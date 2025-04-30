Docker resouce sharing (particularly the kernel) is amazingly lightweight. You can run docker on very
old systems with almost no overhead from running them as a local install (i.e. great for old systems).

You should always try to run the docker command without sudo! This is the standard practice and makes
managing containers much more convenient. It was probably already done at installation, but check that
with 'groups $USER' and add a user to the docker group with 'sudo usermod -aG docker $USER' (replace
$USER with your username if you are not currently logged in as that user when running the command. Note
that groups membership changes require a log off and log back on to take effect.

LinuxServer.io / lscr.io are almost always the best/simplest Docker images to use.
Images by category is probably the easiest way to review them.
https://docs.linuxserver.io/images-by-category/#administration

Docker Desktop Setup
==========
- Windows containers are of limited usefulness for now, just leave that unchecked and connect to WSL2
locally at installation.
- You can install Docker Desktop on a Windows system just to manage containers on a remote Linux system.
Docker Desktop defaults to the local Docker engine (the one it installs inside WSL2), but you can change
it to connect to a remote Docker engine over SSH or TCP.
1. Install Docker Desktop as normal; you don't have to enable/use WSL2 if you don't want to (or you can
just leave it installed, it won't hurt).
2. Connect to your remote Linux machine at Settings → Docker Engine or Settings → Resources → Advanced.
Look for "Docker Daemon" connection settings and tell it to connect via SSH to the remote Linux server.
Or in the Docker CLI, you can just set:
   docker -H ssh://user@remote-server.example.com ps   # -H sets the Docker Host.
3. For permanent config, to always connect to your remote system:
   export DOCKER_HOST=ssh://user@your-remote-linux-ip
Or configure the connection inside the Docker Desktop GUI.
Notes: Your remote server must already have Docker installed and running.
You need SSH access to the remote server (with public key auth ideally for no-password access).
Some GUIs (like the Docker Dashboard) work better than others with remote connections — but it does show
your containers/images etc from the remote server.
You don't need to install WSL2 or a Linux distro locally unless you want to manage local containers too.
VSCode with the Remote Containers extension can also connect over SSH if you want an even easier GUI.

