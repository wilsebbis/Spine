import os
import re
import uuid

def gen_uuid():
    return uuid.uuid4().hex.upper()[:24]

pbx_path = '/Users/wilsebbis/Developer/SpineApp/Spine/Spine.xcodeproj/project.pbxproj'
with open(pbx_path, 'r') as f:
    content = f.read()

files_to_add = [
    ("EconomyService.swift", "Gamification"),
    ("StorefrontView.swift", "Premium"),
    ("ReadingDiaryView.swift", "Profile"),
    ("ReviewEditorView.swift", "Profile")
]

build_files_str = ""
file_refs_str = ""
sources_additions = []
groups_additions = { "Gamification": [], "Premium": [], "Profile": [] }

for name, group in files_to_add:
    if name in content:
        print(f"{name} already in pbxproj")
        continue

    file_uuid = gen_uuid()
    build_uuid = gen_uuid()

    build_files_str += f"\t\t{build_uuid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {name} */; }};\n"
    file_refs_str += f"\t\t{file_uuid} /* {name} */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n"
    
    sources_additions.append(f"\t\t\t\t{build_uuid} /* {name} in Sources */,")
    groups_additions[group].append(f"\t\t\t\t{file_uuid} /* {name} */,")

if build_files_str:
    # 1. Insert into PBXBuildFile section
    content = re.sub(r'(/\* Begin PBXBuildFile section \*/\n)', r'\1' + build_files_str, content)
    
    # 2. Insert into PBXFileReference section
    content = re.sub(r'(/\* Begin PBXFileReference section \*/\n)', r'\1' + file_refs_str, content)
    
    # 3. Add to Sources Build Phase
    build_phase_pattern = r'(/\* Begin PBXSourcesBuildPhase section \*/[\s\S]*?files = \(\n)'
    content = re.sub(build_phase_pattern, r'\1' + "\n".join(sources_additions) + "\n", content, count=1)
    
    # 4. Add to specific groups (assuming Gamification, Premium, Profile exist as groups)
    for group, items in groups_additions.items():
        if not items: continue
        group_pattern = rf'(/\* {group} \*/ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)'
        if re.search(group_pattern, content):
            content = re.sub(group_pattern, r'\1' + "\n".join(items) + "\n", content)
        else:
            print(f"Could not find group for {group}")
            
    with open('/tmp/project.pbxproj', 'w') as f:
        f.write(content)
    
    os.rename('/tmp/project.pbxproj', pbx_path)
    print("Injected files into PBXProj")
else:
    print("Files already exist.")
