#!/usr/bin/python3

import argparse
import os
import subprocess
import sys
import yaml

from typing import (
        Any,
        List,
        NoReturn,
)


def fatal(message: str, status: int = 1) -> NoReturn:
        sys.stderr.write("Fatal: %s\n" % message)
        sys.exit(status)


def mount_bind(what: str, where: str) -> None:
        os.makedirs(what, 0o755, True)
        os.makedirs(where, 0o755, True)
        run_raw(["mount", "--bind", what, where], check=True)


def umount(where: str) -> None:
        run_raw(["umount", "--recursive", "-n", where])


def run_raw(cmdline: List[str], execvp: bool = False, **kwargs: Any) -> subprocess.CompletedProcess:
        if execvp:
                assert not kwargs
                os.execvp(cmdline[0], cmdline)
        else:
                return subprocess.run(cmdline, **kwargs)


def run_command(rootfs: str, cmdline: List[str], envvars: bool, execvp: bool = False, **kwargs: Any) -> None:
        newcmd = ["systemd-nspawn",
                  "--directory=" + rootfs,
                  "--as-pid2",
                  "--register=no"]

        if envvars == True and build_env_vars is not None:
                envars=build_env_vars.split(" ")
                for v in envars:
                        newcmd += [v]

        newcmd.extend(cmdline)
        process = run_raw(newcmd)

        if process.returncode != 0:
                # Force umount anyway
                umount(rootfs)
                fatal("Error: failed command '%s' with code '%d'" % (cmdline[0], process.returncode))


def run_copy(rootfs: str, cmdline: List[str]) -> None:
        if len(cmdline) < 3:
                fatal("Yaml command 'copy' can not find parameters")

        if "--from=" in cmdline[1]:
                params = cmdline[1].split("=")
                if len(params) > 1:
                        src="%s/%s/%s" % (build_dir, params[1], cmdline[2])
                else:
                        fatal("Yaml command 'copy' --from= parameter not valid")
                dest=cmdline[3]
        else:
                src=cmdline[1]
                dest=cmdline[2]

        if dest is None:
                fatal("Yaml command 'copy' destination parameter not set")

        src=os.path.abspath(src)
        if not os.path.exists(src):
                fatal("Yaml command 'copy' source '%s' does not exist" % src)

        newcmd = ["cp", "-d", "-f", "-R",
                  "--preserve=all",
                  src,
                  rootfs + "/" + dest]

        run_raw(newcmd)


def run_script(rootfs: str, cmdline: List[str], envvars: bool) -> None:
        if len(cmdline) < 2:
                fatal("Yaml command 'script' can not find parameters")

        script = cmdline[2]
        if "--from=" in cmdline[1]:
                params = cmdline[1].split("=")
                if len(params) > 1:
                        script="%s/%s/%s" % (build_dir, params[1], script)
                
        if script == "":
                fatal("Yaml command 'script' script file not set")

        # Lets try path of buildspec maybe script in same directory
        if not os.path.exists(script):
                p=os.path.abspath(build_spec)
                script="%s/%s" % (os.path.dirname(p), script)

        if not os.path.exists(script):
                raise FileNotFoundError("Yaml command 'script' could not find script file")

        if os.access(script, os.X_OK) is False:
                fatal("Yaml command 'script' script file '%s' not executable" % script)

        dest="/bin/%s" % (os.path.basename(stript))
        if cmdline[3] is not None:
                dest=cmdline[3]


        script=os.path.abspath(script)
        newcmd = ["--bind=" + script + ":" + dest,
                  dest]

        run_command(rootfs, newcmd, envvars)


def run(rootfs: str, cmdline: List[str], envvars: bool) -> None:
        if len(cmdline) == 0:
                return

        if cmdline[0] == "copy":
                run_copy(rootfs, cmdline)
                return

        mount_bind(rootfs, rootfs)
        if cmdline[0] == "script":
                run_script(rootfs, cmdline, envvars)
        else:
                run_command(rootfs, cmdline, envvars)
        umount(rootfs)


def run_with_shell(rootfs: str, cmdline: List[str]) -> None:
        newcmd = ["/bin/sh", "-xc"]
        newcmd.extend(cmdline)
        run(rootfs, newcmd, False)


class MkiotException(Exception):
        """Fatal sys.exit"""


def parse_args(args=sys.argv[1:]):
        parser = argparse.ArgumentParser(description='Build IoT and Edge applications', add_help=True)
        parser.add_argument("--rootfs", type=str, required=True, help="Root filesystem path, required.")
        parser.add_argument("--buildspec", type=str, help="Buildspec yaml file")
        parser.add_argument("--phase", type=str, help="Yaml phase field path inside buildspec")
        return(parser.parse_known_args(args))


def load_yaml_commands(phase: str) -> List[str]:
        if not os.path.exists(build_spec):
                raise FileNotFoundError("Could not find buildspec file")

        if phase is None:
                raise ValueError("yaml phase field path was not set")

        with open(build_spec, 'r') as f:
                spec = yaml.load(f, Loader=yaml.FullLoader)

        params = phase.split(",")
        if len(params) <= 1:
                raise ValueError("yaml phase field is not valid")

        ph = params[0]
        index = int(params[1])

        if params[0] == "artifacts":
                if index < len(spec["artifacts"]) and "commands" in spec["artifacts"][index]:
                        cmds = spec["artifacts"][index]["commands"]
                        if cmds is not None:
                                print("Info: loading  'buildspec=%s'  'phase=%s[%s]' %d commands" % (build_spec, ph, index, len(cmds)))
                                return cmds

        else:
                # If phase is set continue
                if params[0] in spec["phases"] and index < len(spec["phases"][ph]):
                        if "commands" in spec["phases"][ph][index]:
                                cmds = spec["phases"][ph][index]["commands"]
                                if cmds is not None:
                                        print("Info: loading  'buildspec=%s'  'phase=%s[%s]' %d commands" % (build_spec, ph, index, len(cmds)))
                                        return cmds

        return []


def main() -> None:
        global build_dir
        global build_spec
        global build_env_vars
        global options

        try:
                options, extracmds = parse_args(sys.argv[1:])
                if extracmds is not None and len(extracmds) > 0:
                        s=" "
                        print("Info: 'rootfs=%s'  running  'command=\"%s\"'" %
                              (options.rootfs, s.join(extracmds)))
                        run_with_shell(options.rootfs, extracmds)

                if options.buildspec is not None:
                        if "BUILD_DIRECTORY" not in os.environ:
                                fatal("Environment variable $BUILD_DIRECTORY is not set")

                        build_env_vars = os.getenv("ENV_VARS_PARMS")
                        build_dir = os.getenv('BUILD_DIRECTORY')
                        build_dir = os.path.abspath(build_dir)
                        build_spec = options.buildspec
                        cmds = load_yaml_commands(options.phase)
                        if len(cmds) == 0:
                                return

                        print(cmds)
                        for cmdline in cmds:
                                s=" "
                                print("Info: from 'buildspec=%s'  'rootfs=%s'  running 'command=\"%s\"'" %
                                      (options.buildspec, options.rootfs, s.join(cmdline)))
                                run(options.rootfs, cmdline, True)

        except (MkiotException, MkiotException) as exp:
                fatal(str(exp))


if __name__ == "__main__":
        main()
