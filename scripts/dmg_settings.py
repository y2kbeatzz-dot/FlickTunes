"""Headless Finder presentation settings for the RIFT custom Mac installer.
Uses dmgbuild to write .DS_Store directly: no GUI access or Finder automation.
"""
import os

root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
app = os.path.join(root, ".build", "mac", "Build", "Products", "Release", "RIFT.app")
art = os.path.join(root, ".build", "rift-installer-background.png")
if not os.path.isdir(app):
    raise RuntimeError("Missing built Mac RIFT.app")
if not os.path.isfile(art):
    raise RuntimeError("Missing custom installer background")

files = [app]
symlinks = {"Applications": "/Applications"}
volume_name = "RIFT • Install"
format = "UDZO"
filesystem = "HFS+"
background = art
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
window_rect = ((240, 220), (720, 440))
default_view = "icon-view"
arrange_by = None
icon_size = 100
text_size = 13
label_pos = "bottom"
icon_locations = {"RIFT.app": (155, 200), "Applications": (558, 200)}
hide_extensions = ["RIFT.app"]
