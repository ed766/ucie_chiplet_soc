#!/usr/bin/env python3
"""Install the checksum/revision-pinned external RISC-V validation tools."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCK = ROOT / "verification" / "external_riscv_tools.lock.json"
DEFAULT_INSTALL = ROOT / "build" / "external_riscv_tools"


def run(command: list[str], *, cwd: Path | None = None) -> None:
    subprocess.run(command, cwd=cwd, check=True)


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def clone_revision(repository: str, revision: str, destination: Path) -> None:
    if destination.exists():
        observed = subprocess.run(["git", "-C", str(destination), "rev-parse", "HEAD"],
                                  capture_output=True, text=True).stdout.strip()
        if observed == revision:
            return
        shutil.rmtree(destination)
    run(["git", "clone", "--filter=blob:none", "--no-checkout", repository, str(destination)])
    run(["git", "fetch", "--depth", "1", "origin", revision], cwd=destination)
    run(["git", "checkout", "--detach", "FETCH_HEAD"], cwd=destination)
    observed = subprocess.run(["git", "rev-parse", "HEAD"], cwd=destination,
                              capture_output=True, text=True, check=True).stdout.strip()
    if observed != revision:
        raise RuntimeError(f"{destination.name}: expected {revision}, observed {observed}")


def download(tool: dict[str, object], archive_dir: Path) -> Path:
    path = archive_dir / Path(str(tool["url"])).name
    if not path.exists() or digest(path) != tool["sha256"]:
        path.unlink(missing_ok=True)
        urllib.request.urlretrieve(str(tool["url"]), path)
    observed = digest(path)
    if observed != tool["sha256"]:
        raise RuntimeError(f"{tool['name']}: archive checksum {observed} does not match lock")
    return path


def extract(archive: Path, destination: Path) -> None:
    marker = destination / ".extract_complete"
    if marker.exists():
        return
    shutil.rmtree(destination, ignore_errors=True)
    destination.mkdir(parents=True)
    with tarfile.open(archive, "r:*") as handle:
        handle.extractall(destination, filter="data")
    marker.touch()


def build_spike(source: Path, install: Path) -> None:
    executable = install / "bin" / "spike"
    if executable.exists():
        return
    build = source / "build-codex"
    shutil.rmtree(build, ignore_errors=True)
    build.mkdir()
    run(["../configure", f"--prefix={install}"], cwd=build)
    run(["make", "-j2"], cwd=build)
    run(["make", "install"], cwd=build)


def find_executable(root: Path, name: str) -> Path:
    candidates = [path for path in root.rglob(name) if path.is_file()]
    if not candidates:
        raise FileNotFoundError(f"{name} not found below {root}")
    candidates.sort(key=lambda path: len(path.parts))
    candidates[0].chmod(candidates[0].stat().st_mode | 0o111)
    return candidates[0]


def append_lines(path: str, lines: list[str]) -> None:
    if not path:
        return
    with Path(path).open("a") as handle:
        handle.write("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--install-dir", type=Path, default=DEFAULT_INSTALL)
    parser.add_argument("--github-env", default=os.environ.get("GITHUB_ENV", ""))
    parser.add_argument("--github-path", default=os.environ.get("GITHUB_PATH", ""))
    args = parser.parse_args()
    install = args.install_dir.resolve()
    archive_dir = install / "archives"
    archive_dir.mkdir(parents=True, exist_ok=True)
    tools = {tool["name"]: tool for tool in json.loads(LOCK.read_text())["tools"]}

    spike_home = install / "spike-src"
    act_home = install / "riscv-act"
    formal_home = install / "riscv-formal"
    clone_revision(tools["spike"]["repository"], tools["spike"]["revision"], spike_home)
    clone_revision(tools["riscv-act"]["repository"], tools["riscv-act"]["revision"], act_home)
    clone_revision(tools["riscv-formal"]["repository"], tools["riscv-formal"]["revision"], formal_home)
    spike_install = install / "spike-install"
    build_spike(spike_home, spike_install)

    sail_archive = download(tools["sail-riscv"], archive_dir)
    mise_archive = download(tools["mise"], archive_dir)
    act_gcc_archive = download(tools["act4-gcc"], archive_dir)
    oss_archive = download(tools["oss-cad-suite"], archive_dir)
    sail_root = install / "sail-riscv"
    mise_root = install / "mise"
    act_gcc_root = install / "act4-gcc"
    oss_root = install / "oss-cad-suite"
    extract(sail_archive, sail_root)
    extract(mise_archive, mise_root)
    extract(act_gcc_archive, act_gcc_root)
    extract(oss_archive, oss_root)
    sail_bin = find_executable(sail_root, "sail_riscv_sim")
    mise_bin = find_executable(mise_root, "mise")
    act_gcc_bin = find_executable(act_gcc_root, "riscv-none-elf-gcc")
    sby_bin = find_executable(oss_root, "sby")

    # ACT4's checked-in .mise.toml pins the Ruby and uv versions used by its
    # generator. Provision them without requiring root-owned host packages.
    act_env = os.environ.copy()
    act_env["PATH"] = f"{mise_bin.parent}:{act_gcc_bin.parent}:{act_env.get('PATH', '')}"
    subprocess.run([str(mise_bin), "trust", str(act_home / ".mise.toml")],
                   check=True, env=act_env)
    subprocess.run([str(mise_bin), "install"], cwd=act_home, check=True, env=act_env)

    environment = {
        "SPIKE_HOME": spike_home,
        "RISCV_ACT_HOME": act_home,
        "RISCV_FORMAL_HOME": formal_home,
        "SAIL_RISCV_ARCHIVE": sail_archive,
        "MISE_ARCHIVE": mise_archive,
        "ACT4_GCC_ARCHIVE": act_gcc_archive,
        "OSS_CAD_SUITE_ARCHIVE": oss_archive,
    }
    paths = [spike_install / "bin", sail_bin.parent, mise_bin.parent,
             act_gcc_bin.parent, sby_bin.parent]
    rv32_toolchain_bin = ROOT / "build" / "rv32_toolchain" / "root" / "usr" / "bin"
    if rv32_toolchain_bin.exists():
        paths.append(rv32_toolchain_bin)
    append_lines(args.github_env, [f"{name}={value}" for name, value in environment.items()])
    append_lines(args.github_path, [str(path) for path in paths])
    env_script = install / "environment.sh"
    env_script.write_text("\n".join(
        [*(f"export {name}='{value}'" for name, value in environment.items()),
         f"export PATH='{':'.join(map(str, paths))}':$PATH"]
    ) + "\n")
    print(f"Installed pinned external RISC-V tools; source {env_script}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
