#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""《度日：Daydrift》创作者多体系 Mod SDK 命令行工具 (ddmod_cli.py)

功能：
1. init <mod_id> --tier <1|2|3> : 一键生成对应体系的模组工程骨架与 VSCode 补全环境
2. validate <mod_dir>            : 静态安全审计清单、路径越界与危险二进制文件
3. pack <mod_dir>                : 校验并打包生成规范的 .ddmod / .zip 模组发布包并计算 SHA256
4. dev-link <mod_dir>            : 将开发中模组软链接或同步至游戏运行目录，支持秒级热重载
"""

import sys
import os
import re
import json
import shutil
import hashlib
import zipfile
import argparse
from pathlib import Path

# 适配 Windows 控制台 UTF-8 编码
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

SCRIPT_DIR = Path(__file__).resolve().parent
SCHEMAS_DIR = SCRIPT_DIR / "schemas"
DEFINITIONS_DIR = SCRIPT_DIR / "definitions"
TEMPLATES_DIR = SCRIPT_DIR / "templates"

ID_REGEX = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
VERSION_REGEX = re.compile(r"^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$")
FORBIDDEN_EXTENSIONS = {
    ".exe", ".dll", ".so", ".dylib", ".bat", ".cmd", ".sh",
    ".com", ".msi", ".vbs", ".ps1", ".scr", ".pif", ".cpl"
}
VALID_TYPES = {"data", "lua", "native"}


def cmd_init(args) -> int:
    """初始化模组项目骨架"""
    mod_id = args.mod_id.strip().lower()
    if not ID_REGEX.match(mod_id):
        print(f"[ERROR] 模组 ID '{mod_id}' 不符合命名规范！仅允许小写字母、数字、下划线与连字符（1-64字符）。")
        return 1

    tier = args.tier
    template_map = {
        1: TEMPLATES_DIR / "tier1_data_pack",
        2: TEMPLATES_DIR / "tier2_script_pack",
        3: TEMPLATES_DIR / "tier3_native_pck",
    }
    src_template = template_map.get(tier)
    if not src_template or not src_template.exists():
        print(f"[ERROR] 未找到 Tier {tier} 对应的模板目录：{src_template}")
        return 1

    out_base = Path(args.output).resolve() if args.output else Path.cwd()
    target_dir = out_base / mod_id

    if target_dir.exists():
        print(f"[ERROR] 目标目录已存在：{target_dir}")
        return 1

    print(f"[*] 正在为模组 '{mod_id}' (Tier {tier}) 初始化工程骨架...")
    shutil.copytree(src_template, target_dir)

    # 定制 manifest.json
    manifest_path = target_dir / "manifest.json"
    if manifest_path.exists():
        try:
            with open(manifest_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            data["id"] = mod_id
            if args.name:
                data["name"] = args.name
            if args.author:
                data["author"] = args.author
            with open(manifest_path, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write("\n")
        except Exception as e:
            print(f"[WARN] 定制 manifest.json 出现异常：{e}")

    print(f"[OK] 模组工程初始化成功！")
    print(f"     路径：{target_dir}")
    print(f"     体系：Tier {tier} ({data.get('type')})")
    print(f"     提示：使用 VSCode 打开该目录即可享受完整的 JSON Schema 校验与语法提示。")
    return 0


def cmd_validate(args) -> int:
    """静态审计模组清单与目录安全性"""
    mod_dir = Path(args.mod_dir).resolve()
    if not mod_dir.exists() or not mod_dir.is_dir():
        print(f"[ERROR] 模组目录不存在：{mod_dir}")
        return 1

    print(f"[*] 开始对模组目录执行静态安全审计：{mod_dir.name}")
    manifest_path = mod_dir / "manifest.json"
    if not manifest_path.exists():
        print(f"[FAIL] 缺少必需的 manifest.json 清单文件！")
        return 1

    try:
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest = json.load(f)
    except Exception as e:
        print(f"[FAIL] manifest.json JSON 解析失败：{e}")
        return 1

    # 1. 必填字段校验
    required_fields = ["id", "name", "version", "author", "description", "type"]
    missing = [k for k in required_fields if k not in manifest or not str(manifest[k]).strip()]
    if missing:
        print(f"[FAIL] manifest.json 缺少必填字段：{', '.join(missing)}")
        return 1

    mod_id = str(manifest["id"]).strip()
    if not ID_REGEX.match(mod_id):
        print(f"[FAIL] 模组 ID '{mod_id}' 格式非法！必须满足正则 ^[a-z0-9][a-z0-9_-]{{0,63}}$")
        return 1

    version_str = str(manifest["version"]).strip()
    if not VERSION_REGEX.match(version_str):
        print(f"[FAIL] 模组版本号 '{version_str}' 不符合语义化版本规范 (例如 1.0.0 或 1.0.0-beta)！")
        return 1

    mod_type = str(manifest["type"]).strip().lower()
    if mod_type not in VALID_TYPES:
        print(f"[FAIL] 模组类型 '{mod_type}' 无效！枚举可选值：{VALID_TYPES}")
        return 1

    entry_rel = str(manifest.get("entry", "")).strip()
    if entry_rel:
        clean_entry = entry_rel.replace("\\", "/").lstrip("/")
        if ".." in clean_entry:
            print(f"[FAIL] entry 入口包含非法路径跳转 '..'：{entry_rel}")
            return 1
        entry_abs = mod_dir / clean_entry
        if not entry_abs.exists():
            print(f"[WARN] 声明的入口文件暂不存在：{entry_rel}")

    # 2. 遍历目录执行安全扫描
    illegal_files = []
    traversal_files = []
    total_size = 0
    file_count = 0

    for root, dirs, files in os.walk(mod_dir):
        for file in files:
            p = Path(root) / file
            rel = p.relative_to(mod_dir).as_posix()
            ext = p.suffix.lower()

            if ext in FORBIDDEN_EXTENSIONS:
                illegal_files.append(rel)

            if ".." in rel or rel.startswith("/"):
                traversal_files.append(rel)

            total_size += p.stat().st_size
            file_count += 1

    if illegal_files:
        print(f"[FAIL] 拦截到非法的原生可执行/动态库二进制文件：")
        for fn in illegal_files:
            print(f"       - {fn}")
        return 1

    if traversal_files:
        print(f"[FAIL] 拦截到越界相对路径文件：")
        for fn in traversal_files:
            print(f"       - {fn}")
        return 1

    print(f"[PASS] 模组清单格式合法：{manifest['name']} (ID: {mod_id}, v{version_str}, Type: {mod_type})")
    print(f"[PASS] 文件安全审计通过：共 {file_count} 个文件，总计 {total_size / 1024:.1f} KiB")
    return 0


def cmd_pack(args) -> int:
    """打包生成 .ddmod 发布包"""
    mod_dir = Path(args.mod_dir).resolve()
    # 先做校验
    val_args = argparse.Namespace(mod_dir=str(mod_dir))
    if cmd_validate(val_args) != 0:
        print(f"[ERROR] 静态审计未通过，打包终止！")
        return 1

    manifest_path = mod_dir / "manifest.json"
    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    mod_id = manifest["id"]
    version = manifest["version"]
    default_filename = f"{mod_id}_v{version}.ddmod"

    out_path = Path(args.out).resolve() if args.out else mod_dir.parent / default_filename
    if out_path.is_dir():
        out_path = out_path / default_filename

    print(f"[*] 正在打包模组至：{out_path} ...")

    # 创建 zip 压缩文件
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for root, dirs, files in os.walk(mod_dir):
            for file in sorted(files):
                # 排除临时文件与 VCS 文件
                if file.startswith(".") and file != ".gitattributes":
                    continue
                if file.endswith(".tmp") or file.endswith(".ddmod"):
                    continue

                fp = Path(root) / file
                rel = fp.relative_to(mod_dir).as_posix()
                zf.write(fp, arcname=rel)

    # 计算哈希
    h = hashlib.sha256()
    with open(out_path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    sha256_hex = h.hexdigest()
    pkg_size = out_path.stat().st_size

    print(f"[OK] 模组打包成功！")
    print(f"     包名：{out_path.name}")
    print(f"     大小：{pkg_size / 1024:.2f} KiB ({pkg_size} bytes)")
    print(f"     SHA256: {sha256_hex}")
    return 0


def cmd_dev_link(args) -> int:
    """将开发模组软链接或同步至本地游戏模组目录"""
    mod_dir = Path(args.mod_dir).resolve()
    manifest_path = mod_dir / "manifest.json"
    if not manifest_path.exists():
        print(f"[ERROR] 目录中缺少 manifest.json：{mod_dir}")
        return 1

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)
    mod_id = manifest["id"]

    # 自动探测目标目录
    target_base = None
    if args.target:
        target_base = Path(args.target).resolve()
    elif os.environ.get("DAYDRIFT_MODS_DIR"):
        target_base = Path(os.environ["DAYDRIFT_MODS_DIR"]).resolve()
    else:
        # 探测当前工程下的 Daydrift/mods 或 user://mods
        candidates = [
            Path(r"G:\godot-Project\daydrift\Daydrift\mods"),
            Path.home() / "AppData" / "Roaming" / "Godot" / "app_userdata" / "Daydrift" / "mods",
            Path.home() / ".local" / "share" / "godot" / "app_userdata" / "Daydrift" / "mods",
        ]
        for c in candidates:
            if c.exists() or c.parent.exists():
                target_base = c
                break

    if not target_base:
        target_base = Path.cwd() / "Daydrift" / "mods"

    target_base.mkdir(parents=True, exist_ok=True)
    dest_dir = target_base / mod_id

    print(f"[*] 正在将模组 '{mod_id}' 链接至：{dest_dir} ...")

    # 尝试创建符号链接，若无管理员权限则降级为实时复制
    try:
        if dest_dir.exists():
            if dest_dir.is_symlink():
                dest_dir.unlink()
            else:
                shutil.rmtree(dest_dir)
        os.symlink(mod_dir, dest_dir, target_is_directory=True)
        print(f"[OK] 符号链接创建成功！(秒级热重载已启用)")
    except Exception as sym_err:
        print(f"[INFO] 符号链接失败 ({sym_err})，正在执行目录同步覆盖...")
        shutil.copytree(mod_dir, dest_dir, dirs_exist_ok=True)
        print(f"[OK] 模组文件已同步至目标运行目录！")

    print(f"     启动游戏即可在模组管理器中直接查看与调试。")
    return 0


def main():
    parser = argparse.ArgumentParser(
        description="《度日：Daydrift》三体系 Mod SDK 创作者工具链",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # init
    p_init = subparsers.add_parser("init", help="初始化模组工程骨架")
    p_init.add_argument("mod_id", help="模组唯一命名空间 ID (如 my_first_mod)")
    p_init.add_argument("--tier", type=int, choices=[1, 2, 3], required=True, help="模组体系等级 (1: 数据包, 2: 脚本包, 3: 原生PCK)")
    p_init.add_argument("--name", help="模组展示名称")
    p_init.add_argument("--author", help="作者署名")
    p_init.add_argument("--output", "-o", help="输出根目录 (默认为当前工作目录)")
    p_init.set_defaults(func=cmd_init)

    # validate
    p_val = subparsers.add_parser("validate", help="静态审计模组清单与文件安全性")
    p_val.add_argument("mod_dir", help="模组项目根目录")
    p_val.set_defaults(func=cmd_validate)

    # pack
    p_pack = subparsers.add_parser("pack", help="校验并打包模组分发包 (.ddmod)")
    p_pack.add_argument("mod_dir", help="模组项目根目录")
    p_pack.add_argument("--out", "-o", help="输出文件路径")
    p_pack.set_defaults(func=cmd_pack)

    # dev-link
    p_link = subparsers.add_parser("dev-link", help="将开发中模组链接至游戏运行目录")
    p_link.add_argument("mod_dir", help="模组项目根目录")
    p_link.add_argument("--target", help="目标 mods/ 目录路径")
    p_link.set_defaults(func=cmd_dev_link)

    args = parser.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
