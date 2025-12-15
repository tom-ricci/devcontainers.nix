{
  layered ? false,
}:
{ pkgs, ... }:
let

  fontPkgs = with pkgs; [
    nerd-fonts.jetbrains-mono

    nerd-fonts.symbols-only

    jigmo

    noto-fonts-color-emoji

    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif

    unifont
  ];
in
{
  name = "fontconfig";
  inherit layered;
  executables = with pkgs; [ fontconfig ];
  deps = fontPkgs;
  layers =
    let
      lib = pkgs.lib;

      pkg = pkgs.fontconfig;
      etcFonts = "/etc/fonts";
      allowBitmaps = true;
      useEmbeddedBitmaps = false;
      includeUserConf = true;
      antialias = true;
      cache32Bit = false;
      allowType1 = false;
      fonts.packages = fontPkgs;
      hinting = {
        enable = true;
        autohint = false;
        style = "slight";
      };
      subpixel = {
        rgba = "none";
        lcdfilter = "default";
      };
      jigmo = [
        "Jigmo"
        "Jigmo2"
        "Jigmo3"
      ];
      emoji = [
        "Noto Color Emoji"
      ];

      defaultFonts = {
        serif =
          [ ]
          # 使用 Symbols Nerd Font 专门处理图标
          ++ [ "Symbols Nerd Font" ]
          # 西文优先
          ++ [ "Noto Serif" ]
          # 中文优先
          ++ [ "Noto Serif CJK SC" ]
          # 放在 CJK 之后是为了防止数字和通用标点变成 Emoji 图片，但必须放在生僻字和符号字体之前
          ++ emoji
          # 符号兜底：Noto Sans Symbols
          ++ [
            "Noto Sans Symbols"
            "Noto Sans Symbols 2"
          ]
          # CJK 生僻字兜底
          ++ jigmo;

        sansSerif =
          [ ]
          # 使用 Symbols Nerd Font 专门处理图标，不影响文字
          ++ [ "Symbols Nerd Font" ]
          # 西文优先
          ++ [ "Noto Sans" ]
          # 中文优先
          ++ [ "Noto Sans CJK SC" ]
          # 放在 CJK 之后是为了防止数字和通用标点变成 Emoji 图片，但必须放在生僻字和符号字体之前
          ++ emoji
          # 符号兜底：Noto Sans Symbols
          ++ [
            "Noto Sans Symbols"
            "Noto Sans Symbols 2"
          ]
          # CJK 生僻字兜底
          ++ jigmo
          # 最后的最后：Unifont (以此确保不出现方块，雖然很难看)
          ++ [ "Unifont" ];

        monospace =
          [ ]
          # 注意：等宽环境推荐用 Mono 版本的 Nerd Symbols，以保持对齐
          ++ [ "Symbols Nerd Font Mono" ]
          # Noto Sans Mono 包含 Powerline 符号，但不包含全部 Nerd 图标
          ++ [ "Noto Sans Mono" ]
          # 中文优先
          ++ [ "Noto Sans Mono CJK SC" ]
          # 放在 CJK 之后是为了防止数字和通用标点变成 Emoji 图片，但必须放在生僻字和符号字体之前
          ++ emoji
          # 符号兜底：Noto Sans Symbols
          ++ [
            "Noto Sans Symbols"
            "Noto Sans Symbols 2"
          ]
          # CJK 生僻字兜底
          ++ jigmo;

        emoji = emoji;
      };

      fcBool = x: "<bool>" + (lib.boolToString x) + "</bool>";

      # configuration file to read fontconfig cache
      # priority 0
      cacheConf = makeCacheConf { };

      # generate the font cache setting file
      # When cross-compiling, we can’t generate the cache, so we skip the
      # <cachedir> part. fontconfig still works but is a little slower in
      # looking things up.
      makeCacheConf =
        { }:
        let
          makeCache =
            fontconfig:
            pkgs.makeFontsCache {
              inherit fontconfig;
              fontDirectories = fonts.packages;
            };
          cache = makeCache pkgs.fontconfig;
          cache32 = makeCache pkgs.pkgsi686Linux.fontconfig;
        in
        pkgs.writeText "fc-00-nixos-cache.conf" ''
          <?xml version='1.0'?>
          <!DOCTYPE fontconfig SYSTEM 'urn:fontconfig:fonts.dtd'>
          <fontconfig>
            <!-- Font directories -->
            ${lib.concatStringsSep "\n" (map (font: "<dir>${font}</dir>") fonts.packages)}
            ${lib.optionalString (pkgs.stdenv.hostPlatform.emulatorAvailable pkgs.buildPackages) ''
              <!-- Pre-generated font caches -->
              <cachedir>${cache}</cachedir>
              ${lib.optionalString (pkgs.stdenv.hostPlatform.isx86_64 && cache32Bit) ''
                <cachedir>${cache32}</cachedir>
              ''}
            ''}
          </fontconfig>
        '';

      # rendering settings configuration file
      # priority 10
      renderConf = pkgs.writeText "fc-10-nixos-rendering.conf" ''
        <?xml version='1.0'?>
        <!DOCTYPE fontconfig SYSTEM 'urn:fontconfig:fonts.dtd'>
        <fontconfig>

          <!-- Default rendering settings -->
          <match target="pattern">
            <edit mode="append" name="hinting">
              ${fcBool hinting.enable}
            </edit>
            <edit mode="append" name="autohint">
              ${fcBool hinting.autohint}
            </edit>
          </match>

        </fontconfig>
      '';

      # default fonts configuration file
      # priority 52
      defaultFontsConf =
        let
          genDefault =
            fonts: name:
            lib.optionalString (fonts != [ ]) ''
              <alias binding="same">
                <family>${name}</family>
                <prefer>
                ${lib.concatStringsSep "" (
                  map (font: ''
                    <family>${font}</family>
                  '') fonts
                )}
                </prefer>
              </alias>
            '';
        in
        pkgs.writeText "fc-52-nixos-default-fonts.conf" ''
          <?xml version='1.0'?>
          <!DOCTYPE fontconfig SYSTEM 'urn:fontconfig:fonts.dtd'>
          <fontconfig>

            <!-- Default fonts -->
            ${genDefault defaultFonts.sansSerif "sans-serif"}

            ${genDefault defaultFonts.serif "serif"}

            ${genDefault defaultFonts.monospace "monospace"}

            ${genDefault defaultFonts.emoji "emoji"}

          </fontconfig>
        '';

      # bitmap font options
      # priority 53
      rejectBitmaps = pkgs.writeText "fc-53-no-bitmaps.conf" ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>

        ${lib.optionalString (!allowBitmaps) ''
          <!-- Reject bitmap fonts -->
          <selectfont>
            <rejectfont>
              <pattern>
                <patelt name="scalable"><bool>false</bool></patelt>
              </pattern>
            </rejectfont>
          </selectfont>
        ''}

        <!-- Use embedded bitmaps in fonts like Calibri? -->
        <match target="font">
          <edit name="embeddedbitmap" mode="assign">
            ${fcBool useEmbeddedBitmaps}
          </edit>
        </match>

        </fontconfig>
      '';

      # reject Type 1 fonts
      # priority 53
      rejectType1 = pkgs.writeText "fc-53-nixos-reject-type1.conf" ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>

        <!-- Reject Type 1 fonts -->
        <selectfont>
          <rejectfont>
            <pattern>
              <patelt name="fontformat"><string>Type 1</string></patelt>
            </pattern>
          </rejectfont>
        </selectfont>

        </fontconfig>
      '';

      # Replace default linked config with a different variant
      replaceDefaultConfig = defaultConfig: newConfig: ''
        rm $dst/${defaultConfig}
        ln -s ${pkg.out}/share/fontconfig/conf.avail/${newConfig} \
              $dst/
      '';

      # fontconfig configuration package
      confPkg =
        pkgs.runCommand "fontconfig-conf"
          {
            preferLocalBuild = true;
          }
          ''
            dst=$out/etc/fonts/conf.d
            mkdir -p $dst

            # fonts.conf
            ln -s ${pkg.out}/etc/fonts/fonts.conf \
                  $dst/../fonts.conf
            # TODO: remove this legacy symlink once people stop using packages built before #95358 was merged
            mkdir -p $out/etc/fonts/2.11
            ln -s /etc/fonts/fonts.conf \
                  $out/etc/fonts/2.11/fonts.conf

            # fontconfig default config files
            ln -s ${pkg.out}/etc/fonts/conf.d/*.conf \
                  $dst/

            ${lib.optionalString (!antialias) (
              replaceDefaultConfig "10-yes-antialias.conf" "10-no-antialias.conf"
            )}

            ${lib.optionalString (hinting.style != "slight") (
              replaceDefaultConfig "10-hinting-slight.conf" "10-hinting-${hinting.style}.conf"
            )}

            ${lib.optionalString (subpixel.rgba != "none") (
              replaceDefaultConfig "10-sub-pixel-none.conf" "10-sub-pixel-${subpixel.rgba}.conf"
            )}

            ${lib.optionalString (subpixel.lcdfilter != "default") (
              replaceDefaultConfig "11-lcdfilter-default.conf" "11-lcdfilter-${subpixel.lcdfilter}.conf"
            )}

            ${lib.optionalString allowBitmaps ''
              rm -f $dst/70-no-bitmaps-except-emoji.conf
            ''}

            # 00-nixos-cache.conf
            ln -s ${cacheConf}  $dst/00-nixos-cache.conf

            # 10-nixos-rendering.conf
            ln -s ${renderConf}       $dst/10-nixos-rendering.conf

            # 50-user.conf
            ${lib.optionalString (!includeUserConf) ''
              rm $dst/50-user.conf
            ''}


            # 52-nixos-default-fonts.conf
            ln -s ${defaultFontsConf} $dst/52-nixos-default-fonts.conf

            # 53-no-bitmaps.conf
            ln -s ${rejectBitmaps} $dst/53-no-bitmaps.conf

            ${lib.optionalString (!allowType1) ''
              # 53-nixos-reject-type1.conf
              ln -s ${rejectType1} $dst/53-nixos-reject-type1.conf
            ''}
          '';

    in
    [
      {
        name = "fontconfig /etc/fonts";
        paths = [ confPkg ];
        pathsToLink = [ etcFonts ];
      }
    ];
}
