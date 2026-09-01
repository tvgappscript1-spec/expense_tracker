# LUU Y: Neu ban tao workspace bang template "Flutter" cua IDX / Firebase Studio
# thi file nay DA CO SAN. Chi ghi de khi ban tao workspace trong (blank).
{ pkgs, ... }: {
  # Kenh nixpkgs
  channel = "stable-24.05";

  packages = [
    pkgs.jdk17      # Gradle/AGP hien tai chay tot nhat voi JDK 17
    pkgs.unzip
    pkgs.git
  ];

  env = {
    JAVA_HOME = "${pkgs.jdk17}";
  };

  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];

    workspace = {
      onCreate = {
        # Chay 1 lan khi tao workspace
        pub-get = "flutter pub get";
        default.openFiles = [ "lib/main.dart" ];
      };
      onStart = {
        # Chay moi lan mo lai workspace
        pub-get = "flutter pub get";
      };
    };

    previews = {
      enable = true;
      previews = {
        android = {
          command = [ "flutter" "run" "--machine" "-d" "android" ];
          manager = "flutter";
        };
      };
    };
  };
}
