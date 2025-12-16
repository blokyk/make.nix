{ pkgs, ... }: {
  run = cmd: { name, ... }: pkgs.runCommandCC name {} cmd;
}