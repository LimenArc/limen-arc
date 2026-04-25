#!/usr/bin/env python3
"""
Generates LuckyBlockRealm.rbxlx from the Rojo source tree.
Run from the repo root: python3 gen_rbxlx.py
"""

import os, uuid, xml.etree.ElementTree as ET
from xml.etree.ElementTree import Element, SubElement

SRC = os.path.join(os.path.dirname(__file__), "src")
OUT = os.path.join(os.path.dirname(__file__), "LuckyBlockRealm.rbxlx")

_ref_counter = [0]
def ref():
    _ref_counter[0] += 1
    return f"RBX{_ref_counter[0]:032X}"

def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

def script_name(filename):
    """Strip .server.lua / .client.lua / .lua extensions."""
    for ext in (".server.lua", ".client.lua", ".lua"):
        if filename.endswith(ext):
            return filename[: -len(ext)]
    return filename

def script_class(filename):
    if filename.endswith(".server.lua"):
        return "Script"
    if filename.endswith(".client.lua"):
        return "LocalScript"
    return "ModuleScript"

# ── XML helpers ────────────────────────────────────────────────────────────

def item(parent, class_name, referent=None):
    el = SubElement(parent, "Item")
    el.set("class", class_name)
    el.set("referent", referent or ref())
    return el

def props(parent):
    return SubElement(parent, "Properties")

def prop_str(props_el, name, value):
    e = SubElement(props_el, "string")
    e.set("name", name)
    e.text = value
    return e

def prop_bool(props_el, name, value):
    e = SubElement(props_el, "bool")
    e.set("name", name)
    e.text = "true" if value else "false"
    return e

def prop_int(props_el, name, value):
    e = SubElement(props_el, "int")
    e.set("name", name)
    e.text = str(value)
    return e

def prop_float(props_el, name, value):
    e = SubElement(props_el, "float")
    e.set("name", name)
    e.text = str(value)
    return e

def prop_source(props_el, source):
    e = SubElement(props_el, "ProtectedString")
    e.set("name", "Source")
    e.text = source   # ElementTree will CDATA-wrap as needed
    return e

def prop_color3(props_el, name, r, g, b):
    e = SubElement(props_el, "Color3")
    e.set("name", name)
    e.text = f"4294967295"   # white placeholder; Studio recalculates
    # Roblox stores Color3 as a uint32 ARGB; use sub-elements for RGB float
    re = SubElement(e, "R"); re.text = str(r/255)
    ge = SubElement(e, "G"); ge.text = str(g/255)
    be = SubElement(e, "B"); be.text = str(b/255)
    return e

def prop_vector3(props_el, name, x, y, z):
    e = SubElement(props_el, "Vector3")
    e.set("name", name)
    xe = SubElement(e, "X"); xe.text = str(x)
    ye = SubElement(e, "Y"); ye.text = str(y)
    ze = SubElement(e, "Z"); ze.text = str(z)
    return e

def prop_cframe(props_el, name, px, py, pz):
    e = SubElement(props_el, "CoordinateFrame")
    e.set("name", name)
    for tag, val in [("X",px),("Y",py),("Z",pz),
                     ("R00","1"),("R01","0"),("R02","0"),
                     ("R10","0"),("R11","1"),("R12","0"),
                     ("R20","0"),("R21","0"),("R22","1")]:
        c = SubElement(e, tag); c.text = str(val)
    return e

# ── Script item factory ───────────────────────────────────────────────────

def add_script(parent, path, name_override=None):
    filename  = os.path.basename(path)
    cls       = script_class(filename)
    sname     = name_override or script_name(filename)
    source    = read(path)
    it        = item(parent, cls)
    p         = props(it)
    prop_str(p, "Name", sname)
    prop_source(p, source)
    prop_bool(p, "Disabled", False)
    return it

def add_folder(parent, name):
    it = item(parent, "Folder")
    p  = props(it)
    prop_str(p, "Name", name)
    return it

# ── Build DataModel ───────────────────────────────────────────────────────

root_el = Element("roblox")
root_el.set("xmlns:xmime", "http://www.w3.org/2005/05/xmlmime")
root_el.set("xmlns:xsi",   "http://www.w3.org/2001/XMLSchema-instance")
root_el.set("xsi:noNamespaceSchemaLocation", "http://www.roblox.com/roblox.xsd")
root_el.set("version", "4")

meta = SubElement(root_el, "Meta"); meta.set("name","ExplicitAutoJoints"); meta.text="true"
SubElement(root_el, "External").text = "null"
SubElement(root_el, "External").text = "nil"

dm = item(root_el, "DataModel", "RBX00000000000000000000000000000000")
dm_props = props(dm)
prop_str(dm_props, "Name", "LuckyBlockRealm")

# ── Workspace ─────────────────────────────────────────────────────────────

ws = item(dm, "Workspace")
ws_p = props(ws)
prop_str(ws_p, "Name", "Workspace")
prop_bool(ws_p, "FilteringEnabled", True)
prop_float(ws_p, "Gravity", 196.2)

# SpawnLocation
sl = item(ws, "SpawnLocation")
sl_p = props(sl)
prop_str(sl_p, "Name", "SpawnLocation")
prop_cframe(sl_p, "CFrame", 0, 6, 30)
prop_vector3(sl_p, "size", 8, 1, 8)
prop_color3(sl_p, "Color", 240, 200, 80)
prop_str(sl_p, "Material", "Enum.Material.Neon")
prop_bool(sl_p, "Anchored", True)
prop_bool(sl_p, "AllowTeamChangeOnTouch", False)
prop_bool(sl_p, "Neutral", True)
prop_int(sl_p, "Duration", 0)

# CurrentCamera
cam = item(ws, "Camera")
cam_p = props(cam)
prop_str(cam_p, "Name", "Camera")

# ── Lighting ──────────────────────────────────────────────────────────────

lt = item(dm, "Lighting")
lt_p = props(lt)
prop_str(lt_p, "Name", "Lighting")
prop_float(lt_p, "Brightness", 2)
prop_float(lt_p, "ClockTime", 14)
prop_float(lt_p, "GeographicLatitude", 41.7)
prop_color3(lt_p, "Ambient", 128, 128, 128)
prop_color3(lt_p, "ColorShift_Bottom", 0, 0, 0)
prop_color3(lt_p, "ColorShift_Top", 0, 0, 0)
prop_bool(lt_p, "GlobalShadows", True)

# Sky
sky = item(lt, "Sky")
sky_p = props(sky)
prop_str(sky_p, "Name", "Sky")

# Atmosphere
atm = item(lt, "Atmosphere")
atm_p = props(atm)
prop_str(atm_p, "Name", "Atmosphere")
prop_float(atm_p, "Density", 0.3)
prop_float(atm_p, "Offset", 0.25)
prop_float(atm_p, "Haze", 0)
prop_float(atm_p, "Glare", 0)
prop_color3(atm_p, "Color", 199, 199, 199)
prop_color3(atm_p, "Decay", 106, 127, 153)

# ── ReplicatedStorage ─────────────────────────────────────────────────────

rs = item(dm, "ReplicatedStorage")
rs_p = props(rs)
prop_str(rs_p, "Name", "ReplicatedStorage")

# Remotes module
add_script(rs, os.path.join(SRC, "ReplicatedStorage", "Remotes.lua"), "Remotes")

# Modules folder
mods_folder = add_folder(rs, "Modules")
modules_dir = os.path.join(SRC, "ReplicatedStorage", "Modules")
for fname in sorted(os.listdir(modules_dir)):
    if fname.endswith(".lua"):
        add_script(mods_folder, os.path.join(modules_dir, fname))

# ── ServerScriptService ───────────────────────────────────────────────────

sss = item(dm, "ServerScriptService")
sss_p = props(sss)
prop_str(sss_p, "Name", "ServerScriptService")

sss_dir = os.path.join(SRC, "ServerScriptService")
for fname in sorted(os.listdir(sss_dir)):
    if fname.endswith(".lua"):
        add_script(sss, os.path.join(sss_dir, fname))

# ── StarterPlayer ─────────────────────────────────────────────────────────

sp = item(dm, "StarterPlayer")
sp_p = props(sp)
prop_str(sp_p, "Name", "StarterPlayer")

sps = item(sp, "StarterPlayerScripts")
sps_p = props(sps)
prop_str(sps_p, "Name", "StarterPlayerScripts")

sps_dir = os.path.join(SRC, "StarterPlayer", "StarterPlayerScripts")
for fname in sorted(os.listdir(sps_dir)):
    if fname.endswith(".lua"):
        add_script(sps, os.path.join(sps_dir, fname))

# StarterCharacterScripts (may be empty but add the container)
scs = item(sp, "StarterCharacterScripts")
scs_p = props(scs)
prop_str(scs_p, "Name", "StarterCharacterScripts")

char_dir = os.path.join(SRC, "StarterPlayer", "StarterCharacterScripts")
if os.path.isdir(char_dir):
    for fname in sorted(os.listdir(char_dir)):
        if fname.endswith(".lua"):
            add_script(scs, os.path.join(char_dir, fname))

# ── StarterGui ────────────────────────────────────────────────────────────

sg = item(dm, "StarterGui")
sg_p = props(sg)
prop_str(sg_p, "Name", "StarterGui")

starter_gui_dir = os.path.join(SRC, "StarterGui")
if os.path.isdir(starter_gui_dir):
    for fname in sorted(os.listdir(starter_gui_dir)):
        if fname.endswith(".lua"):
            add_script(sg, os.path.join(starter_gui_dir, fname))

# ── ServerStorage ─────────────────────────────────────────────────────────

ss = item(dm, "ServerStorage")
ss_p = props(ss)
prop_str(ss_p, "Name", "ServerStorage")

ss_dir = os.path.join(SRC, "ServerStorage")
if os.path.isdir(ss_dir):
    for fname in sorted(os.listdir(ss_dir)):
        if fname.endswith(".lua"):
            add_script(ss, os.path.join(ss_dir, fname))

# ── Teams, SoundService, TextChatService stubs ───────────────────────────

for cls in ("Teams", "SoundService", "TextChatService"):
    stub = item(dm, cls)
    stub_p = props(stub)
    prop_str(stub_p, "Name", cls)

# ── Write XML ─────────────────────────────────────────────────────────────

def indent(el, level=0):
    pad = "\n" + "  " * level
    if len(el):
        if not el.text or not el.text.strip():
            el.text = pad + "  "
        if not el.tail or not el.tail.strip():
            el.tail = pad
        for child in el:
            indent(child, level + 1)
        # Fix last child tail
        if not child.tail or not child.tail.strip():
            child.tail = pad
    else:
        if level and (not el.tail or not el.tail.strip()):
            el.tail = pad

indent(root_el)

tree = ET.ElementTree(root_el)
ET.register_namespace("xmime", "http://www.w3.org/2005/05/xmlmime")
ET.register_namespace("xsi",   "http://www.w3.org/2001/XMLSchema-instance")

# Write with xml declaration
with open(OUT, "w", encoding="utf-8") as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n')
    # ElementTree doesn't do CDATA natively; we post-process ProtectedString content
    import io
    buf = io.StringIO()
    tree.write(buf, encoding="unicode", xml_declaration=False)
    xml_str = buf.getvalue()

    # Wrap ProtectedString text content in CDATA
    import re
    def cdata_replace(m):
        tag_open = m.group(1)
        content  = m.group(2)
        tag_close = m.group(3)
        # content is already XML-escaped by ElementTree; unescape it then re-wrap in CDATA
        content = content.replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&").replace("&quot;", '"').replace("&#13;", "\r")
        return f"{tag_open}<![CDATA[{content}]]>{tag_close}"

    xml_str = re.sub(
        r'(<ProtectedString[^>]*>)([\s\S]*?)(</ProtectedString>)',
        cdata_replace,
        xml_str
    )
    f.write(xml_str)

print(f"Written: {OUT}")
print(f"Size: {os.path.getsize(OUT):,} bytes")
