#!/bin/bash

set -o xtrace

function debug {
  echo "==> $1"
}

function init {
  ROOT_UID=0
  if [ $ROOT_UID -ne $UID ]
  then
    debug "Run this script as ROOT"
    exit 1
  fi
}

function stop_daemon {
  debug "Stop sshd"
  systemctl stop sshd
}

function setup_hostname {
  debug "Setup hostname"
  eth2ip=$(ip a show eth2 | grep "inet " | awk '{print $2}' | sed 's/\/[0-9]*//')
  echo "$eth2ip $(hostname -s) $(hostname)" >> /etc/hosts
}

function remove_session_cache {
  debug "Remove cache"
  rm -rf /home/moi/.cache/session
}

function setup_ssh_proxy {
  debug "Setup ssh proxy"
  apt-get install -y corkscrew > /dev/null

  touch ~/.ssh/config
  sed -i '1s/^/ProxyCommand /usr/bin/corkscrew  proxy.tpr.univ-lyon1.fr 3128 %h %p\n/' ~/.ssh/config
}

function setup_proxy {
  debug "Setup proxy"
  cat << EOF >> ~/.zshrc
export ALL_PROXY=http://proxy.tpr.univ-lyon1.fr:3128/
export FTP_PROXY=http://proxy.tpr.univ-lyon1.fr:3128/
export HTTPS_PROXY=http://proxy.tpr.univ-lyon1.fr:3128/
export HTTP_PROXY=http://proxy.tpr.univ-lyon1.fr:3128/
export NO_PROXY='localhost,*.tpr.univ-lyon1.fr,.tpr.univ-lyon1.fr<Plug>PeepOpent-localhost.netacad.com'
EOF
  setup_ssh_proxy
}

function install_base_packages {
  debug "Install base packages"
  apt-get update > /dev/null
  apt-get install -y screen git curl wget htop > /dev/null
}

function install_vim {
  debug "Install VIM"
  apt-get install -y vim > /dev/null
  git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime
  sh ~/.vim_runtime/install_awesome_vimrc.sh

  sed -i 's/set shiftwidth=.*$/set shiftwidth=2/' ~/.vim_runtime/vimrcs/basic.vim
  sed -i 's/set tabstop=.*$/set tabstop=2/' ~/.vim_runtime/vimrcs/basic.vim
  sed -i '1s/^/let g:go_version_warning = 0\n/' ~/.vim_runtime/sources_non_forked/vim-go/plugin/go.vim
}

function install_zsh {
  debug "Install ZSH"
  apt-get install -y zsh fonts-powerline > /dev/null

  curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh | bash -
  sed -i 's/ZSH_THEME=.*$/ZSH_THEME="agnoster"/' ~/.zshrc
  sed -i 's/# (ENABLE_CORRECTION="true")/\1/' ~/.zshrc

  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh-syntax-highlighting
  cat << EOF >> ~/.zshrc
export EDITOR=vim
export DEFAULT_USER=moi
source ~/.zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
EOF

  chsh -s /bin/zsh
  chsh -s /bin/zsh moi

}

function install_grc {
  debug "Install GRC"
  apt-get install -y zsh fonts-powerline grc > /dev/null

  cat << EOF > /etc/grc.zsh
if [[ "$TERM" != dumb ]] && (( \$+commands[grc] )) ; then
  # Prevent grc aliases from overriding zsh completions.
  setopt COMPLETE_ALIASES

  # Supported commands
  cmds=(
    cc \\
    configure \\
    cvs \\
    df \\
    diff \\
    dig \\
    gcc \\
    gmake \\
    ifconfig \\
    last \\
    ldap \\
    ls \\
    make \\
    mount \\
    mtr \\
    netstat \\
    ping \\
    ping6 \\
    ps \\
    traceroute \\
    traceroute6 \\
    wdiff \\
    ip \\
  );

  # Set alias for available commands.
  for cmd in \$cmds ; do
    if (( \$+commands[\$cmd] )) ; then
      alias \$cmd="grc --colour=auto \$cmd"
    fi
  done

  # Clean up variables
  unset cmds cmd
fi
EOF

  cat << EOF >> ~/.zshrc
if [ -f /etc/grc.zsh ]; then
  source /etc/grc.zsh
fi
EOF

}

function setup_aliases {
  debug "Setup aliases"
  cat << EOF > ~/.zsh_aliases
alias sl=ls
alias l='ls -GFah'
alias grep='grep --color'
alias ..='cd ..'

function cl () {
  cd $1
  ls
}
EOF

  cat << EOF >> ~/.zshrc
if [ -f ~/.zsh_aliases ]; then
  source ~/.zsh_aliases
fi
EOF
}

function Main {
  init
  stop_daemon
  setup_hostname
  remove_session_cache
  install_base_packages
  install_vim
  install_zsh
  install_grc
  setup_proxy
  zsh
}

Main
