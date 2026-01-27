{
  hosts_os = {
    elcunal = {
      system = "x86_64-linux";
      file = ./elcunal;
      hostname = "elcunal";
    };
    elcunhp1 = {
      system = "x86_64-linux";
      file = ./hp_1;
      hostname = "elcunhp1";
    };

    elcungem = {
      system = "x86_64-linux";
      file = ./elcungem;
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
