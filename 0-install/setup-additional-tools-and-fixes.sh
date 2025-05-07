#!/bin/bash

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31mElevation required; rerunning as sudo...\033[0m\n"
    exec sudo "$0" "$@"
fi

# Function to display and run a command then check its success
run_command() {
    echo -e "\033[1;33mRunning: $1\033[0m"
    eval "$1"
    if [ $? -ne 0 ]; then
        echo -e "\033[31mError: Command failed - $1\033[0m\n"
        exit 1
    fi
}

# Function to prompt user before running a section
run_section_prompt() {
    local section="$1"
    local function_name="$2"
    echo ""
    echo -e "\033[1;33m=== $section ===\033[0m"

    # Extract and display everything in a function's body including comments, so that user can decide on running or not
    awk "/^${function_name}\(\) *\{/,/^}/ {if (!match(\$0, /^${function_name}\(\) *\{/) && \$0 != \"}\") print}" "$0"

    echo ""  
    read -p "Run this section? (y/N): " choice
    case "$choice" in
        y|Y ) $function_name;;
        * ) echo "Skipping $section.";;
    esac
}

# Read this script to get all functions then prompt if the user wants to run each one by one
run_functions() {
    for func in $(awk '/^[a-zA-Z_][a-zA-Z0-9_]*\(\) *\{/{print substr($1, 1, length($1)-2)}' "$0" | grep -Ev '^(run_command|run_section_prompt|run_functions|run_function_summary)$'); do  
        run_section_prompt "$func" "$func"  
        echo ""  
    done  
    echo "All selected sections completed."
}

# Display a summary of all function names and descriptions
run_function_summary() {
    for func in $(awk '/^[a-zA-Z_][a-zA-Z0-9_]*\(\) *\{/{print substr($1, 1, length($1)-2)}' "$0" | grep -Ev '^(run_command|run_section_prompt|run_functions|run_function_summary)$'); do
        # Extract the first comment line from the function body
        description=$(awk "/^${func}\(\) *\{/,/^}/ {if (!match(\$0, /^${func}\(\) *\{/) && \$0 ~ /^#/) {print substr(\$0, 3); exit}}" "$0")
        
        # Print the function name with the description
        if [ -n "$description" ]; then
            echo "$func # $description"
        else
            echo "$func # No description available"
        fi
    done
    echo "All sections listed."
}

####################
#
# Each function will be displayed as a section that the user can choose to execute or not
#
####################


update_system() {
# Section: Update and upgrade the system
  run_command "apt-get update -y"
  run_command "apt-get upgrade -y"
  run_command "apt-get dist-upgrade -y"
}

install_common_utilities() {
# Section: Install common utilities
  run_command "apt-get install -y curl wget git vim tmux htop ncdu tree unzip"
}

install_development_tools() {
# Section: Install development tools
  run_command "apt-get install -y build-essential cmake python3 python3-pip"
}

install_network_tools() {
# Section: Install network tools
  run_command "apt-get install -y net-tools dnsutils nmap tcpdump"
}

install_multimedia_tools() {
# Section: Install multimedia tools
  run_command "apt-get install -y ffmpeg vlc"
}

install_security_tools() {
# Section: Install security tools
  run_command "apt-get install -y ufw fail2ban"
  run_command "ufw allow ssh"
  run_command "ufw allow http"
  run_command "ufw allow https"
  run_command "ufw enable"
}

install_samba() {
# Section: Install and configure Samba
  run_command "apt-get install -y samba"
  run_command "echo '
[shared]
   path = /srv/samba/shared
   browseable = yes
   writable = yes
   create mask = 0777
   directory mask = 0777
   public = yes' >> /etc/samba/smb.conf"
  run_command "mkdir -p /srv/samba/shared"
  run_command "chmod -R 777 /srv/samba/shared"
  run_command "systemctl restart smbd"
}

install_ssh() {
# Section: Install and configure SSH
  run_command "apt-get install -y openssh-server"
  # Example of modifying sshd_config to disable root login via ssh:
  #    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
  run_command "systemctl restart ssh"
}

install_ntp() {
# Section: Install and configure NTP
  run_command "apt-get install -y ntp"
  run_command "systemctl restart ntp"
}

install_docker() {
# Section: Install and configure Docker
  run_command "apt-get install -y docker.io"
  run_command "systemctl enable docker"
  run_command "systemctl start docker"
  run_command "usermod -aG docker $USER"
}

install_git() {
# Section: Install and configure Git
  run_command "apt-get install -y git"
  run_command "git config --global user.name 'Your Name'"
  run_command "git config --global user.email 'your.email@example.com'"
}

install_zsh() {
# Section: Install and configure ZSH with Oh-My-Zsh
  run_command "apt-get install -y zsh"
  run_command "sh -c '$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)'"
  run_command "chsh -s $(which zsh)"
}

install_nodejs() {
# Section: Install and configure Node.js and npm
  run_command "curl -fsSL https://deb.nodesource.com/setup_16.x | bash -"
  run_command "apt-get install -y nodejs"
}

install_postgresql() {
# Section: Install and configure PostgreSQL
  run_command "apt-get install -y postgresql postgresql-contrib"
  run_command "systemctl start postgresql"
  run_command "systemctl enable postgresql"
}

install_mysql() {
# Section: Install and configure MySQL
  run_command "apt-get install -y mysql-server"
  run_command "systemctl start mysql"
  run_command "systemctl enable mysql"
}

install_php() {
# Section: Install and configure PHP
  run_command "apt-get install -y php php-cli php-fpm php-mysql php-pgsql php-curl php-gd php-mbstring php-xml php-zip"
}

install_apache() {
# Section: Install and configure Apache
  run_command "apt-get install -y apache2"
  run_command "systemctl start apache2"
  run_command "systemctl enable apache2"
}

install_nginx() {
# Section: Install and configure Nginx
  run_command "apt-get install -y nginx"
  run_command "systemctl start nginx"
  run_command "systemctl enable nginx"
}

install_certbot() {
# Section: Install and configure "Let's Encrypt (Certbot)"
  run_command "apt-get install -y certbot python3-certbot-apache python3-certbot-nginx"
}

install_virtualbox() {
# Section: Install and configure VirtualBox
  run_command "apt-get install -y virtualbox virtualbox-ext-pack"
}

install_vagrant() {
# Section: Install and configure Vagrant
  run_command "apt-get install -y vagrant"
}

install_ansible() {
# Section: Install and configure Ansible
  run_command "apt-get install -y ansible"
}

# Section: Install and configure Kubernetes tools
install_kubernetes_tools() {
  run_command "apt-get install -y kubectl kubeadm kubelet"
}

install_terraform() {
# Section: Install and configure Terraform
  run_command "apt-get install -y terraform"
}

install_aws_cli() {
# Section: Install and configure AWS CLI
  run_command "apt-get install -y awscli"
}

install_google_cloud_sdk() {
# Section: Install and configure Google Cloud SDK
  run_command "echo 'deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main' | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list"
  run_command "curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -"
  run_command "apt-get update -y"
  run_command "apt-get install -y google-cloud-sdk"
}

install_azure_cli() {
# Section: Install and configure Azure CLI
  run_command "curl -sL https://aka.ms/InstallAzureCLIDeb | bash"
}

install_flatpak() {
# Section: Install and configure Flatpak
  run_command "apt-get install -y flatpak"
  run_command "flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo"
}

install_snap() {
# Section: Install and configure Snap
  run_command "apt-get install -y snapd"
  run_command "systemctl enable snapd"
  run_command "systemctl start snapd"
}

install_docker_compose() {
# Section: Install and configure Docker Compose
  echo   # dummy line as function with only comments will throw an error
  # Below command is not playing nicely with run_command, needs work on escaping inside " etc
  # run_command "curl -L 'https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*\d")'/docker-compose-$(uname -s)-$(uname -m)' -o /usr/local/bin/docker-compose"
  # run_command "chmod +x /usr/local/bin/docker-compose"
}

install_java() {
# Section: Install and configure Java
  run_command "apt-get install -y default-jdk"
}

install_maven() {
# Section: Install and configure Maven
  run_command "apt-get install -y maven"
}

install_gradle() {
# Section: Install and configure Gradle
  run_command "apt-get install -y gradle"
}

install_go() {
# Section: Install and configure Go
  run_command "apt-get install -y golang"
}

install_rust() {
# Section: Install and configure Rust
  run_command "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
}

install_ruby() {
# Section: Install and configure Ruby
  run_command "apt-get install -y ruby-full"
}

install_python_virtualenv() {
# Section: Install and configure Python virtualenv
  run_command "pip3 install virtualenv"
}

install_jupyter() {
# Section: Install and configure Jupyter Notebook
  run_command "pip3 install jupyterlab"
}

install_pandoc() {
# Section: Install and configure Pandoc
  run_command "apt-get install -y pandoc"
}

install_texlive() {
# Section: Install and configure TeX Live
  run_command "apt-get install -y texlive-full"
}

install_timeshift() {
# Section: Install and configure Timeshift
  run_command "apt-get install -y timeshift"
}

final_configuration() {
# Any wrap-up steps, restart services etc
  echo   # dummy line so that the function is not empty
  # run_command "sudo systemctl restart apache2"
}
run_function_summary
run_functions
