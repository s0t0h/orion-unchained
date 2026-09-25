// SPDX-License-Identifier: GPL-2.0-or-later
/*
 * Lighting driver for Acer Predator Orion desktops.
 *
 * The case lighting of these machines (front panel, fans, liquid cooler) is
 * run by board firmware behind the AcerGamingFunction WMI class. Its ACPI
 * method (WMBH) only copies the request into a mailbox and raises a software
 * SMI, so all hardware access happens in firmware, exactly as on Windows.
 *
 * This driver sends the same requests as PredatorSense's
 * AcerDTECDeviceController.dll, byte for byte:
 *
 *   method 5  SetGamingLedBehavior(u8 in[16])   effect, speed, duration, direction
 *   method 7  SetGamingRgbSetting(u64 in)       colour, brightness
 *   method 6  GetGamingLedBehavior(u64 in)      read back effect
 *   method 8  GetGamingRgbSetting(u32 in)       read back colour
 *
 * At probe every area is read back: areas the firmware rejects are hidden and
 * the rest start from their real state. Replies are 8 bytes and byte 0 is a
 * status (0 = ok, 1 = no such area): LedBehavior continues with enable, mode,
 * speed, duration; RgbSetting with red, green, blue, brightness.
 *
 * Area numbers follow PredatorSense. On the PO7-660: 1 CPU cooler, 2 front
 * fans, 3 radiator fans, 4 rear fan, 6 memory; 0 addresses all of them.
 *
 * The same class carries fan control, CPU overclocking and system
 * configuration methods. They are never called.
 */

#include <linux/bitops.h>
#include <linux/cleanup.h>
#include <linux/debugfs.h>
#include <linux/delay.h>
#include <linux/device.h>
#include <linux/dmi.h>
#include <linux/kernel.h>
#include <linux/kstrtox.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/seq_file.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/sysfs.h>
#include <linux/types.h>
#include <linux/version.h>
#include <linux/wmi.h>

#define ACER_GAMING_FUNCTION_GUID	"7A4DDFE7-5B5D-40B4-8595-4408E0CC7F56"

#define METHOD_SET_LED_BEHAVIOR		5
#define METHOD_GET_LED_BEHAVIOR		6
#define METHOD_SET_RGB_SETTING		7
#define METHOD_GET_RGB_SETTING		8

/* PredatorSense sleeps this long after every lighting call. */
#define SETTLE_MS			20

#define SMBIOS_TYPE_ACER_OEM		172

#define MODE_OFF			0xfe
#define SPEED_MAX			9
#define SPEED_DEFAULT			5
#define DURATION_MAX			9
#define BRIGHTNESS_MAX			100
#define DIRECTION_MAX			1

static bool force;
module_param(force, bool, 0444);
MODULE_PARM_DESC(force, "Bind on Acer desktops that have not been verified");

static bool enable_dimm;
module_param(enable_dimm, bool, 0444);
MODULE_PARM_DESC(enable_dimm, "Offer the memory lighting area when firmware reports one");

enum predator_area {
	AREA_GLOBAL,
	AREA_1,
	AREA_2,
	AREA_3,
	AREA_4,
	AREA_5,
	AREA_DIMM,
	AREA_COUNT,
};

static const char * const predator_area_names[AREA_COUNT] = {
	"global", "area1", "area2", "area3", "area4", "area5", "dimm",
};

struct predator_mode {
	const char *name;
	u8 id;
	bool random;	/* random colour offered (global area only) */
	bool dimm;	/* offered for memory lighting */
};

/* Modes and flags as defined by PredatorSense's RGBController_AcerDT* classes. */
static const struct predator_mode predator_modes[] = {
	{ "static",	0x00,	  false, true  },
	{ "breathing",	0x01,	  true,  true  },
	{ "heartbeat",	0x02,	  true,  true  },
	{ "twinkling",	0x03,	  true,  true  },
	{ "rainbow",	0x06,	  false, true  },
	{ "wave",	0x09,	  true,  false },
	{ "risen",	0x0a,	  false, true  },
	{ "stack",	0x0b,	  false, false },
	{ "extend",	0x0c,	  false, false },
	{ "meteorite",	0x0d,	  false, false },
	{ "magic",	0x0e,	  false, false },
	{ "snake",	0x0f,	  true,  false },
	{ "off",	MODE_OFF, false, true  },
};

struct predator_zone {
	u8 mode;	/* index into predator_modes */
	u8 red;
	u8 green;
	u8 blue;
	u8 brightness;
	u8 speed;
	u8 duration;
	u8 direction;
	bool random;
};

struct predator_rgb {
	struct wmi_device *wdev;
	struct mutex lock;	/* serialises firmware calls and zone state */
	u8 smbios_major;
	u8 smbios_minor;
	bool smbios_found;
	bool direction_payload;	/* 16-byte LedBehavior payload, SMBIOS 172 v6.2+ */
	unsigned long areas;	/* areas the firmware accepts */
	struct predator_zone zones[AREA_COUNT];
};

static const struct dmi_system_id predator_dmi_table[] = {
	{
		.ident = "Acer Predator PO7-660",
		.matches = {
			DMI_MATCH(DMI_SYS_VENDOR, "Acer"),
			DMI_MATCH(DMI_PRODUCT_NAME, "Predator PO7-660"),
		},
	},
	{ }
};

static bool predator_mode_allowed(enum predator_area area, unsigned int mode)
{
	return area != AREA_DIMM || predator_modes[mode].dimm;
}

/* Effects that ignore the colour get 0x02, all others 0x03 (AcerDTSetMode). */
static u8 predator_rgb_flags(u8 mode_id)
{
	switch (mode_id) {
	case 0x06:
	case 0x0a ... 0x0e:
		return 0x02;
	default:
		return 0x03;
	}
}

/* Invoke a method of instance 0 and copy up to 8 reply bytes into @reply. */
static int predator_invoke(struct wmi_device *wdev, u32 method, const void *in,
			   size_t in_len, u8 reply[8])
{
#if LINUX_VERSION_CODE >= KERNEL_VERSION(7, 0, 0)
	struct wmi_buffer input = { .length = in_len, .data = (void *)in };
	struct wmi_buffer output;
	int ret;

	ret = wmidev_invoke_method(wdev, 0, method, &input, &output, sizeof(u32));
	if (ret)
		return ret;

	memcpy(reply, output.data, min_t(size_t, output.length, 8));
	kfree(output.data);

	return 0;
#else
	struct acpi_buffer input = { .length = in_len, .pointer = (void *)in };
	struct acpi_buffer output = { ACPI_ALLOCATE_BUFFER, NULL };
	union acpi_object *obj;
	acpi_status status;
	int ret = 0;

	status = wmidev_evaluate_method(wdev, 0, method, &input, &output);
	if (ACPI_FAILURE(status))
		return -EIO;

	obj = output.pointer;
	if (obj && obj->type == ACPI_TYPE_BUFFER && obj->buffer.length >= sizeof(u32))
		memcpy(reply, obj->buffer.pointer, min_t(u32, obj->buffer.length, 8));
	else
		ret = -EPROTO;
	kfree(obj);

	return ret;
#endif
}

static int predator_call(struct predator_rgb *priv, u32 method, const void *in,
			 size_t in_len, u8 reply[8])
{
	int ret;

	memset(reply, 0, 8);
	ret = predator_invoke(priv->wdev, method, in, in_len, reply);
	msleep(SETTLE_MS);

	return ret;
}

static int predator_apply(struct predator_rgb *priv, enum predator_area area,
			  const struct predator_zone *zone)
{
	const struct predator_mode *mode = &predator_modes[zone->mode];
	struct device *dev = &priv->wdev->dev;
	u8 led[16] = { };
	u8 rgb[8] = { };
	u8 reply[8];
	size_t led_len;
	int ret;

	lockdep_assert_held(&priv->lock);

	led[0] = BIT(area);
	led[2] = mode->id != MODE_OFF;
	led[3] = mode->id;
	led[5] = zone->speed;
	led[6] = zone->duration;
	led[7] = zone->random;		/* colour type: 0 fixed, 1 random */
	if (priv->direction_payload) {
		led[4] = 0x0f;
		led[8] = zone->direction;
		led_len = sizeof(led);
	} else {
		/* Older firmware takes a u64 with no direction and 0x07 here. */
		led[4] = 0x07;
		led_len = sizeof(u64);
	}

	ret = predator_call(priv, METHOD_SET_LED_BEHAVIOR, led, led_len, reply);
	dev_dbg(dev, "SetGamingLedBehavior %*ph -> %d, reply %8ph\n",
		(int)led_len, led, ret, reply);
	if (ret)
		return ret;

	rgb[0] = BIT(area);
	rgb[2] = zone->red;
	rgb[3] = zone->green;
	rgb[4] = zone->blue;
	rgb[5] = zone->brightness;
	rgb[6] = predator_rgb_flags(mode->id);

	ret = predator_call(priv, METHOD_SET_RGB_SETTING, rgb, sizeof(rgb), reply);
	dev_dbg(dev, "SetGamingRgbSetting %8ph -> %d, reply %8ph\n", rgb, ret, reply);

	return ret;
}

/*
 * Read an area back from firmware. Returns -ENODEV when the firmware rejects
 * the area (non-zero status byte), which is also how PredatorSense decides
 * whether memory lighting exists.
 */
static int predator_read_zone(struct predator_rgb *priv, enum predator_area area)
{
	struct predator_zone *zone = &priv->zones[area];
	__le64 led_in = cpu_to_le64(BIT(area));
	__le32 rgb_in = cpu_to_le32(BIT(area));
	u8 led[8], rgb[8];
	unsigned int i;
	int ret;

	lockdep_assert_held(&priv->lock);

	ret = predator_call(priv, METHOD_GET_LED_BEHAVIOR, &led_in, sizeof(led_in), led);
	if (ret)
		return ret;
	if (led[0])
		return -ENODEV;

	ret = predator_call(priv, METHOD_GET_RGB_SETTING, &rgb_in, sizeof(rgb_in), rgb);
	if (ret)
		return ret;

	for (i = 0; i < ARRAY_SIZE(predator_modes); i++) {
		if (predator_modes[i].id == (led[1] ? led[2] : MODE_OFF) &&
		    predator_mode_allowed(area, i))
			zone->mode = i;
	}
	zone->speed = min_t(u8, led[3], SPEED_MAX);
	zone->duration = min_t(u8, led[4], DURATION_MAX);

	if (!rgb[0]) {
		zone->red = rgb[1];
		zone->green = rgb[2];
		zone->blue = rgb[3];
		zone->brightness = min_t(u8, rgb[4], BRIGHTNESS_MAX);
	}

	return 0;
}

/* Validate a candidate zone state and push it; the cached state only changes on success. */
static int predator_update(struct predator_rgb *priv, enum predator_area area,
			   struct predator_zone *zone)
{
	int ret;

	lockdep_assert_held(&priv->lock);

	if (!predator_mode_allowed(area, zone->mode))
		return -EINVAL;
	if (zone->random && (area != AREA_GLOBAL || !predator_modes[zone->mode].random))
		zone->random = false;

	ret = predator_apply(priv, area, zone);
	if (ret)
		return ret;

	priv->zones[area] = *zone;

	/* Firmware copies a global effect to every area; mirror that in the cache. */
	if (area == AREA_GLOBAL) {
		unsigned int i;

		for_each_set_bit(i, &priv->areas, AREA_DIMM)
			if (i != AREA_GLOBAL)
				priv->zones[i] = *zone;
	}

	return 0;
}

static int predator_parse_mode(enum predator_area area, const char *buf)
{
	unsigned int i;

	for (i = 0; i < ARRAY_SIZE(predator_modes); i++)
		if (sysfs_streq(buf, predator_modes[i].name))
			return predator_mode_allowed(area, i) ? i : -EINVAL;

	return -EINVAL;
}

static int predator_parse_color(const char *buf, struct predator_zone *zone)
{
	char hex[7];
	u32 rgb;

	if (sysfs_streq(buf, "random")) {
		zone->random = true;
		return 0;
	}

	if (*buf == '#')
		buf++;
	if (strcspn(buf, "\n") != 6)
		return -EINVAL;
	memcpy(hex, buf, 6);
	hex[6] = '\0';
	if (kstrtou32(hex, 16, &rgb))
		return -EINVAL;

	zone->red = rgb >> 16;
	zone->green = rgb >> 8;
	zone->blue = rgb;
	zone->random = false;

	return 0;
}

static int predator_parse_u8(const char *buf, u8 max, u8 *val)
{
	u8 v;

	if (kstrtou8(buf, 0, &v) || v > max)
		return -EINVAL;
	*val = v;

	return 0;
}

struct zone_attribute {
	struct device_attribute dev_attr;
	enum predator_area area;
};

#define to_zone_area(attr) container_of(attr, struct zone_attribute, dev_attr)->area

static ssize_t mode_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	struct predator_rgb *priv = dev_get_drvdata(dev);
	enum predator_area area = to_zone_area(attr);
	unsigned int i;
	int len = 0;

	guard(mutex)(&priv->lock);

	for (i = 0; i < ARRAY_SIZE(predator_modes); i++) {
		if (!predator_mode_allowed(area, i))
			continue;
		len += sysfs_emit_at(buf, len, i == priv->zones[area].mode ? "[%s] " : "%s ",
				     predator_modes[i].name);
	}
	buf[len - 1] = '\n';

	return len;
}

static ssize_t mode_store(struct device *dev, struct device_attribute *attr,
			  const char *buf, size_t count)
{
	struct predator_rgb *priv = dev_get_drvdata(dev);
	enum predator_area area = to_zone_area(attr);
	struct predator_zone zone;
	int mode, ret;

	mode = predator_parse_mode(area, buf);
	if (mode < 0)
		return mode;

	guard(mutex)(&priv->lock);

	zone = priv->zones[area];
	zone.mode = mode;
	ret = predator_update(priv, area, &zone);

	return ret ?: count;
}

static ssize_t color_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	struct predator_rgb *priv = dev_get_drvdata(dev);
	const struct predator_zone *zone = &priv->zones[to_zone_area(attr)];

	guard(mutex)(&priv->lock);

	if (zone->random)
		return sysfs_emit(buf, "random\n");

	return sysfs_emit(buf, "%02x%02x%02x\n", zone->red, zone->green, zone->blue);
}

static ssize_t color_store(struct device *dev, struct device_attribute *attr,
			   const char *buf, size_t count)
{
	struct predator_rgb *priv = dev_get_drvdata(dev);
	enum predator_area area = to_zone_area(attr);
	struct predator_zone zone;
	int ret;

	guard(mutex)(&priv->lock);

	zone = priv->zones[area];
	ret = predator_parse_color(buf, &zone);
	if (ret)
		return ret;
	if (zone.random && (area != AREA_GLOBAL || !predator_modes[zone.mode].random))
		return -EINVAL;
	ret = predator_update(priv, area, &zone);

	return ret ?: count;
}

#define PREDATOR_U8_ATTR(_name, _max)							\
static ssize_t _name##_show(struct device *dev, struct device_attribute *attr,		\
			    char *buf)							\
{											\
	struct predator_rgb *priv = dev_get_drvdata(dev);				\
											\
	guard(mutex)(&priv->lock);							\
											\
	return sysfs_emit(buf, "%u\n", priv->zones[to_zone_area(attr)]._name);		\
}											\
											\
static ssize_t _name##_store(struct device *dev, struct device_attribute *attr,	\
			     const char *buf, size_t count)				\
{											\
	struct predator_rgb *priv = dev_get_drvdata(dev);				\
	enum predator_area area = to_zone_area(attr);					\
	struct predator_zone zone;							\
	u8 val;										\
	int ret;									\
											\
	ret = predator_parse_u8(buf, _max, &val);					\
	if (ret)									\
		return ret;								\
											\
	guard(mutex)(&priv->lock);							\
											\
	zone = priv->zones[area];							\
	zone._name = val;								\
	ret = predator_update(priv, area, &zone);					\
											\
	return ret ?: count;								\
}

PREDATOR_U8_ATTR(brightness, BRIGHTNESS_MAX)
PREDATOR_U8_ATTR(speed, SPEED_MAX)
PREDATOR_U8_ATTR(duration, DURATION_MAX)
PREDATOR_U8_ATTR(direction, DIRECTION_MAX)

/*
 * Set several properties with a single firmware update, e.g.
 * "mode=breathing color=ff0000 speed=3 duration=3 brightness=80 direction=0".
 */
static ssize_t effect_store(struct device *dev, struct device_attribute *attr,
			    const char *buf, size_t count)
{
	struct predator_rgb *priv = dev_get_drvdata(dev);
	enum predator_area area = to_zone_area(attr);
	struct predator_zone zone;
	char *str, *cur, *tok, *val;
	int ret = 0;

	str = kstrndup(buf, count, GFP_KERNEL);
	if (!str)
		return -ENOMEM;

	guard(mutex)(&priv->lock);

	zone = priv->zones[area];
	cur = strim(str);
	while ((tok = strsep(&cur, " \t")) && !ret) {
		if (!*tok)
			continue;
		val = strchr(tok, '=');
		if (!val) {
			ret = -EINVAL;
			break;
		}
		*val++ = '\0';

		if (!strcmp(tok, "mode")) {
			ret = predator_parse_mode(area, val);
			if (ret >= 0) {
				zone.mode = ret;
				ret = 0;
			}
		} else if (!strcmp(tok, "color")) {
			ret = predator_parse_color(val, &zone);
		} else if (!strcmp(tok, "brightness")) {
			ret = predator_parse_u8(val, BRIGHTNESS_MAX, &zone.brightness);
		} else if (!strcmp(tok, "speed")) {
			ret = predator_parse_u8(val, SPEED_MAX, &zone.speed);
		} else if (!strcmp(tok, "duration")) {
			ret = predator_parse_u8(val, DURATION_MAX, &zone.duration);
		} else if (!strcmp(tok, "direction")) {
			ret = predator_parse_u8(val, DIRECTION_MAX, &zone.direction);
		} else {
			ret = -EINVAL;
		}
	}
	kfree(str);
	if (ret)
		return ret;

	if (zone.random && (area != AREA_GLOBAL || !predator_modes[zone.mode].random))
		return -EINVAL;
	ret = predator_update(priv, area, &zone);

	return ret ?: count;
}

/* Zone controls are group-writable so a udev rule can hand them to a group. */
#define ZONE_ATTR_RW(_zone, _name)						\
	static struct zone_attribute _zone##_##_name = {			\
		.dev_attr = __ATTR(_name, 0664, _name##_show, _name##_store),	\
		.area = _zone,							\
	}

#define ZONE_ATTR_WO(_zone, _name)						\
	static struct zone_attribute _zone##_##_name = {			\
		.dev_attr = __ATTR(_name, 0220, NULL, _name##_store),		\
		.area = _zone,							\
	}

#define ZONE_ATTRS(_zone)							\
	ZONE_ATTR_RW(_zone, mode);						\
	ZONE_ATTR_RW(_zone, color);						\
	ZONE_ATTR_RW(_zone, brightness);					\
	ZONE_ATTR_RW(_zone, speed);						\
	ZONE_ATTR_RW(_zone, duration);						\
	ZONE_ATTR_RW(_zone, direction);						\
	ZONE_ATTR_WO(_zone, effect);						\
	static struct attribute *_zone##_attrs[] = {				\
		&_zone##_mode.dev_attr.attr,					\
		&_zone##_color.dev_attr.attr,					\
		&_zone##_brightness.dev_attr.attr,				\
		&_zone##_speed.dev_attr.attr,					\
		&_zone##_duration.dev_attr.attr,				\
		&_zone##_direction.dev_attr.attr,				\
		&_zone##_effect.dev_attr.attr,					\
		NULL								\
	}

ZONE_ATTRS(AREA_GLOBAL);
ZONE_ATTRS(AREA_1);
ZONE_ATTRS(AREA_2);
ZONE_ATTRS(AREA_3);
ZONE_ATTRS(AREA_4);
ZONE_ATTRS(AREA_5);
ZONE_ATTRS(AREA_DIMM);

/* Hide the directory of an area the firmware does not accept (6.9+), else its files. */
static umode_t zone_attr_visible(struct kobject *kobj, struct attribute *attr, int n)
{
	struct predator_rgb *priv = dev_get_drvdata(kobj_to_dev(kobj));
	enum predator_area area = to_zone_area(container_of(attr, struct device_attribute, attr));

	if (test_bit(area, &priv->areas))
		return attr->mode;
#ifdef SYSFS_GROUP_INVISIBLE
	if (n == 0)
		return SYSFS_GROUP_INVISIBLE;
#endif
	return 0;
}

#define ZONE_GROUP(_var, _name, _zone)						\
	static const struct attribute_group _var = {				\
		.name = _name,							\
		.attrs = _zone##_attrs,						\
		.is_visible = zone_attr_visible,				\
	}

ZONE_GROUP(global_group, "global", AREA_GLOBAL);
ZONE_GROUP(area1_group, "area1", AREA_1);
ZONE_GROUP(area2_group, "area2", AREA_2);
ZONE_GROUP(area3_group, "area3", AREA_3);
ZONE_GROUP(area4_group, "area4", AREA_4);
ZONE_GROUP(area5_group, "area5", AREA_5);
ZONE_GROUP(dimm_group, "dimm", AREA_DIMM);

static ssize_t smbios_version_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	struct predator_rgb *priv = dev_get_drvdata(dev);

	if (!priv->smbios_found)
		return sysfs_emit(buf, "none\n");

	return sysfs_emit(buf, "%u.%u\n", priv->smbios_major, priv->smbios_minor);
}
static DEVICE_ATTR_RO(smbios_version);

static ssize_t zones_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	struct predator_rgb *priv = dev_get_drvdata(dev);
	unsigned int area;
	int len = 0;

	for_each_set_bit(area, &priv->areas, AREA_COUNT)
		len += sysfs_emit_at(buf, len, "%s ", predator_area_names[area]);
	if (!len)
		return sysfs_emit(buf, "\n");
	buf[len - 1] = '\n';

	return len;
}
static DEVICE_ATTR_RO(zones);

static struct attribute *predator_attrs[] = {
	&dev_attr_smbios_version.attr,
	&dev_attr_zones.attr,
	NULL
};

static const struct attribute_group predator_group = { .attrs = predator_attrs };

static const struct attribute_group *predator_groups[] = {
	&predator_group,
	&global_group,
	&area1_group,
	&area2_group,
	&area3_group,
	&area4_group,
	&area5_group,
	&dimm_group,
	NULL
};

/* Raw firmware read-back of every area, for reverse engineering. */
static int state_show(struct seq_file *s, void *unused)
{
	struct predator_rgb *priv = s->private;
	unsigned int area;
	u8 led[8], rgb[8];
	int ret;

	guard(mutex)(&priv->lock);

	for (area = 0; area < AREA_COUNT; area++) {
		__le64 led_in = cpu_to_le64(BIT(area));
		__le32 rgb_in = cpu_to_le32(BIT(area));

		ret = predator_call(priv, METHOD_GET_LED_BEHAVIOR, &led_in, sizeof(led_in), led);
		if (ret)
			return ret;
		ret = predator_call(priv, METHOD_GET_RGB_SETTING, &rgb_in, sizeof(rgb_in), rgb);
		if (ret)
			return ret;

		seq_printf(s, "%-6s led %8ph  rgb %8ph\n", predator_area_names[area], led, rgb);
	}

	return 0;
}
DEFINE_SHOW_ATTRIBUTE(state);

static void predator_debugfs_remove(void *data)
{
	debugfs_remove_recursive(data);
}

/* Acer's OEM structure starts with a version byte pair (PredatorSense takes the first one). */
static void predator_find_smbios(const struct dmi_header *dm, void *data)
{
	struct predator_rgb *priv = data;
	const u8 *raw = (const u8 *)dm;

	if (priv->smbios_found || dm->type != SMBIOS_TYPE_ACER_OEM || dm->length < 6)
		return;

	priv->smbios_major = raw[4];
	priv->smbios_minor = raw[5];
	priv->smbios_found = true;
}

static int predator_probe(struct wmi_device *wdev, const void *context)
{
	struct device *dev = &wdev->dev;
	struct predator_rgb *priv;
	struct dentry *debugfs;
	unsigned int i;
	int ret;

	if (!dmi_check_system(predator_dmi_table)) {
		if (!force)
			return dev_err_probe(dev, -ENODEV,
					     "unverified model, load with force=1 to bind anyway\n");
		dev_warn(dev, "binding on an unverified model\n");
	}

	priv = devm_kzalloc(dev, sizeof(*priv), GFP_KERNEL);
	if (!priv)
		return -ENOMEM;

	priv->wdev = wdev;
	mutex_init(&priv->lock);

	dmi_walk(predator_find_smbios, priv);
	priv->direction_payload = priv->smbios_found && priv->smbios_major == 6 &&
				  priv->smbios_minor >= 2;

	for (i = 0; i < AREA_COUNT; i++) {
		priv->zones[i] = (struct predator_zone) {
			.red = 0xff, .green = 0xff, .blue = 0xff,
			.brightness = BRIGHTNESS_MAX,
			.speed = SPEED_DEFAULT,
		};
	}

	scoped_guard(mutex, &priv->lock) {
		for (i = 0; i < AREA_COUNT; i++) {
			if (i == AREA_DIMM && !enable_dimm)
				continue;
			ret = predator_read_zone(priv, i);
			if (ret == -ENODEV)
				continue;
			if (ret)
				return dev_err_probe(dev, ret, "reading %s failed\n",
						     predator_area_names[i]);
			__set_bit(i, &priv->areas);
		}
	}
	if (!priv->areas)
		return dev_err_probe(dev, -ENODEV, "firmware reports no lighting areas\n");

	dev_set_drvdata(dev, priv);

	debugfs = debugfs_create_dir("acer_predator_dt_rgb", NULL);
	debugfs_create_file("state", 0400, debugfs, priv, &state_fops);
	ret = devm_add_action_or_reset(dev, predator_debugfs_remove, debugfs);
	if (ret)
		return ret;

	dev_info(dev, "SMBIOS 172 %s%u.%u, %s payload, areas %#lx\n",
		 priv->smbios_found ? "v" : "missing, assuming v", priv->smbios_major,
		 priv->smbios_minor, priv->direction_payload ? "16-byte" : "8-byte",
		 priv->areas);

	return 0;
}

static const struct wmi_device_id predator_wmi_ids[] = {
	{ .guid_string = ACER_GAMING_FUNCTION_GUID },
	{ }
};
MODULE_DEVICE_TABLE(wmi, predator_wmi_ids);

static struct wmi_driver predator_driver = {
	.driver = {
		.name = "acer-predator-dt-rgb",
		.dev_groups = predator_groups,
	},
	.id_table = predator_wmi_ids,
	.probe = predator_probe,
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 9, 0)
	.no_singleton = true,
#endif
};
module_wmi_driver(predator_driver);

MODULE_AUTHOR("Orion Unchained contributors");
MODULE_DESCRIPTION("Acer Predator Orion desktop lighting");
MODULE_VERSION("0.1.0");
MODULE_LICENSE("GPL");
