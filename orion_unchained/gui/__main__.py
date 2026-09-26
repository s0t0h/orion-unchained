# SPDX-License-Identifier: GPL-2.0-or-later
"""python3 -m orion_unchained.gui"""
import sys

from ..core import reexec_with_group

reexec_with_group(["-m", "orion_unchained.gui", *sys.argv[1:]])

from .app import main  # noqa: E402

main()
