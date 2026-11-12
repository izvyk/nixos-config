{ config, inputs, ... }:
# metal-stack's mini-lab (github.com/metal-stack/mini-lab) in a KVM guest.
# The lab needs root: containerlab runs under sudo, starts privileged
# containers that run QEMU on /dev/kvm, and wires up bridges and routes; kind
# runs Kubernetes in docker. That can't be squeezed into a user-namespaced
# container, and granting it on the host would make dev effectively root
# here. So the VM is the boundary and the inside is wide open: dev gets
# docker and passwordless sudo, no firewall, no service hardening.
#   - own kernel; root inside is not root here.
#   - only the store paths of its own system, on a read-only disk image (no
#     virtiofsd on the host, no nix daemon socket).
#   - egress is NATed to the public internet only (sandbox-net.nix). The host
#     may connect in, nothing else can.
#   - QEMU runs as the unprivileged `microvm` user.
# Inside, the switches and test machines are nested VMs: QEMU passes the host
# CPU through, vmx included, and kvm_intel nests by default.
#
# Not started at boot. Run it, as dev on tortila:
#   doas systemctl start microvm@minilab
#   ssh dev@10.233.1.2              # from buratino: ssh -J tortila dev@10.233.1.2
#   git clone https://github.com/metal-stack/mini-lab && cd mini-lab
#   make MONITORING_ENABLED=false   # first run downloads ~10 GB of images
#
# Sizing for the default `sonic` flavor: two switch VMs at 4 GiB and two
# machine VMs at 2 GiB, plus the kind control plane. Ballooning hands memory
# the guest frees back to tortila, so after `make cleanup` it shrinks again.
let
  hostAddress = "10.233.1.1";
  vmAddress = "10.233.1.2";
  tap = "vm-minilab";
  mac = "02:00:00:00:01:02";
  sshKeys = config.users.users.dev.openssh.authorizedKeys.keys;
in
{
  imports = [ inputs.microvm.nixosModules.host ];

  microvm.vms.minilab = {
    autostart = false;
    config =
      { pkgs, ... }:
      {
        system.stateVersion = "26.05";

        microvm = {
          vcpu = 6; # all of tortila's cores; idle vCPUs cost nothing
          mem = 20480;
          balloon = true;
          interfaces = [
            {
              type = "tap";
              id = tap;
              inherit mac;
              # Packets go through the kernel instead of QEMU: much faster,
              # and the lab pulls a lot of images.
              tap.vhost = true;
            }
          ];
          # A persistent root, like an ordinary VM: docker's images, the lab
          # checkout, SSH host keys. Sparse, created on first start under
          # /var/lib/microvms/minilab/.
          volumes = [
            {
              image = "root.img";
              label = "minilab-root";
              mountPoint = "/";
              size = 100 * 1024;
            }
          ];
        };

        networking = {
          useDHCP = false;
          # Only the host can reach the VM (sandbox-net.nix), and a firewall
          # here would only get in docker's and containerlab's way.
          firewall.enable = false;
          # The host's resolver is on the blocked side. Public resolvers also
          # answer the lab's *.nip.io names, which some routers filter as
          # DNS rebinding.
          nameservers = [
            "9.9.9.9"
            "1.1.1.1"
          ];
        };
        # By MAC: docker and containerlab create plenty of other ethernet links.
        systemd.network.networks."10-uplink" = {
          matchConfig.MACAddress = mac;
          address = [ "${vmAddress}/24" ];
          gateway = [ hostAddress ];
        };

        services.openssh = {
          enable = true;
          settings.PasswordAuthentication = false;
        };

        virtualisation.docker.enable = true;

        users.users.dev = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "docker"
          ];
          shell = pkgs.fish;
          openssh.authorizedKeys.keys = sshKeys;
        };
        programs.fish.enable = true;
        # The Makefile calls sudo itself.
        security.sudo.wheelNeedsPassword = false;

        # What the Makefile calls; the rest (yq, cfssl, ansible, metalctl)
        # runs in containers it pulls. With cosign it also verifies the
        # deployment image's signature.
        environment.systemPackages = with pkgs; [
          containerlab
          kind
          kubectl
          gnumake
          git
          jq
          cosign
          tmux
        ];
      };
  };

  # microvm.nix installs this cap_net_admin helper, runnable by every user, for
  # `type = "bridge"` interfaces. A tap doesn't need it.
  security.wrappers.qemu-bridge-helper.enable = false;

  systemd.network.networks."30-${tap}" = {
    matchConfig.Name = tap;
    address = [ "${hostAddress}/24" ];
    # Only exists while the VM runs.
    linkConfig.RequiredForOnline = "no";
  };

  sandbox.interfaces = [ tap ];
}
