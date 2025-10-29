{
  hosts_os = {
    asus-laptop = {
      system = "x86_64-linux";
      file = ./asus-laptop;
      hostname = "elcunal";
    };
    hp_1 = {
      system = "x86_64-linux";
      file = ./hp_1;
      hostname = "elcunhp1";
    };

    gemos = {
      system = "x86_64-linux";
      file = ./gemos;
      hostname = "elcungem";
    };
    opizero3 = {
      system = "aarch64-linux";
      file = ./opizero3;
      hostname = "opizero3";
    };

  };
  hosts_hm = {
    wsl2 = {
      system = "x86_64-linux";
      file = ./wsl2.nix;
    };
  };
}
