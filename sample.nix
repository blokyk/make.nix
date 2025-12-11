with import <nixpkgs> {};
let
  nix-make = callPackage ./. {};
  make = userMod: lib.evalModules {
    modules = [
      (import <./module>)
      userMod
    ];
  };

  mkAction = nix-make.utils.mkAction;
  mkAlias = nix-make.utils.mkAlias;
in with nix-make.utils.stdenv;
make {
  targets = rec {
    flash = mkAction {
      # nativeBuildInputs = [ pkgs.openfpgaloader ];
      # buildInputs = [ build-display ];
      cmd = "${pkgs.openFPGALoader} -b basys3 --bitstream ${build-display}";
    };

    build-display = mkAlias "bin/display.bit";

    "bin/%.bit" = mkPattern {
      # nativeBuildInputs = [ xc7frames2bit ];
      buildInputs = [
        # "obj/%.frames"
        # "basys3-parts.yaml"
      ];
      cmd = dep: ''
        ${xc7frames2bit} \
          --part_file "${dep "basys3-parts.yaml"}" \
          --part_name "basys3" \
          --frm_file  "${dep "obj/%.frames"}" \
          --output_file "$out"
      '';
    };

    "basys3-parts.yaml" = mkRule {
      # buildInputs = [artix7-db];
      cmd = ''cp "${artix7-db}/basys3/parts.yml" "$out"'';
    };

    "obj/%.frames" = mkPattern {
      # nativeBuildInputs = [ fasm2frames ];
      buildInputs = [
        # "obj/%.fasm"
      ];
      cmd = dep: ''
        ${fasm2frames} \
          --part "basys3" \
          --db-root "${artix7-db}" \
          "${dep "obj/%.fasm"}" \
          > "$out"
      '';
    };

    "obj/%.fasm" = mkPattern {
      # nativeBuildInputs = [ nextpnr-xilinx ];
      buildInputs = [
        # "obj/%.json"
        # "%.xdc"
      ];

      cmd = dep: out: ''
        ${nextpnr-xilinx} --quiet \
          --chipdb "${chipdb.basys3}"
          --xdc    "${dep "%.xdc"}"
          --json   "${dep "obj/%.json"}"
          --write  "${out "obj/%_routed.json"}"
          --fasm   "$out" # should we still allow this even when using the `getOutput` function?
      '';
    };

    "obj/%.json" = mkPattern (captures: {
      nativeBuildInputs = [ pkgs.yosys-ghdl ];
      cmd = dep:
        let
          mod-name = elemAt captures 0;
          script = writeText "ghdl-syn.yosys" ''
            ghdl ''$(cat "${dep "obj/%-srcs"}") -e ${mod-name};
            synth_xilinx -flatten -abc9 -nobram -arch xc7 -top ${mod_name};
            write_json "$out"
          '';
        in ''
          ${pkgs.yosys} -q -m ghdl ${script}
        '';
    });

    "obj/display-srcs" = mkPattern {
      cmd = dep:
        let
          inherit (lif.fileset) fileFilter toList;
          # list all files
          vhdFileset = fileFilter (file: file.hasExt "vhd") ./.;
          inputFiles = map dep (toList vhdFileset);
        in ''
          echo ${inputFiles} > "$out"
        '';
    };
  };
}