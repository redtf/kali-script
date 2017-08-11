# Original idea by g0tmi1k (https://github.com/g0tmi1k/os-scripts)
##### (Cosmetic) Colour output
RED="\033[01;31m"      # Issues/Errors
GREEN="\033[01;32m"    # Success
YELLOW="\033[01;33m"   # Warnings/Information
BLUE="\033[01;34m"     # Heading
BOLD="\033[01;01m"     # Highlight
RESET="\033[00m"       # Normal

BANNER="\n${BOLD}[!] ${RED}[Red]${RESET} ${RED}[T]${RESET}${BOLD}eam ${RED}[F]${RESET}${BOLD}ield [!]${RESET}"
for i in {1..5}
do
  echo -e $BANNER
done
echo -e "\n${YELLOW}[!]${RESET} The installation will start in 5 seconds"

sleep 5

#--- Remove this folders
echo -e "\n${GREEN}[+]${RESET} Removing dummy folders"
rm -r /root/Public /root/Documents /root/Music /root/Pictures /root/Videos /root/Templates 2>/dev/null

#--- Disable auto notification
echo -e "\n${GREEN}[+]${RESET} Disable its auto notification package update"
export DISPLAY=:0.0
timeout 5 killall -w /usr/lib/apt/methods/http > /dev/null 2>&1

#--- Disable screensaver
echo -e "\n${GREEN}[+]${RESET} Disable screensaver"
gsettings set org.gnome.desktop.session idle-delay 0

#--- Add architecture i386
echo -e "\n${GREEN}[+]${RESET} Architecture i386"
dpkg --add-architecture i386

echo -e "\n${GREEN}[+]${RESET} Enable default network repositories"
#--- Add network repositories
file=/etc/apt/sources.list; [ -e "${file}" ] && cp -n $file{,.bkup}
([[ -e "${file}" && "$(tail -c 1 ${file})" != "" ]]) && echo >> "${file}"
#--- Main
grep -q '^deb .* kali-rolling' "${file}" 2>/dev/null \
  || echo -e "\n\n# Kali Rolling\ndeb http://http.kali.org/kali kali-rolling main contrib non-free" >> "${file}"
#--- Source
grep -q '^deb-src .* kali-rolling' "${file}" 2>/dev/null \
  || echo -e "deb-src http://http.kali.org/kali kali-rolling main contrib non-free" >> "${file}"
#--- Disable CD repositories
sed -i '/kali/ s/^\( \|\t\|\)deb cdrom/#deb cdrom/g' "${file}"
#--- Incase we were interrupted
dpkg --configure -a
#--- Update
apt -qq update
if [[ "$?" -ne 0 ]]; then
  echo -e ' '${RED}'[!]'${RESET}" There was an ${RED}issue accessing network repositories${RESET}" 1>&2
  echo -e " ${YELLOW}[i]${RESET} Are the remote network repositories ${YELLOW}currently being sync'd${RESET}?"
  echo -e " ${YELLOW}[i]${RESET} Here is ${BOLD}YOUR${RESET} local network ${BOLD}repository${RESET} information (Geo-IP based):\n"
  curl -sI http://http.kali.org/README
  exit 1
fi
#--- Set keyboard es,es
setxkbmap -layout 'es,es' -model 'pc105'
##### Update OS from network repositories
echo -e "\n${GREEN}[+]${RESET}  ${GREEN}Updating OS${RESET} from network repositories"
echo -e " ${YELLOW}[i]${RESET}  ...this ${BOLD}may take a while${RESET} depending on your Internet connection & Kali version/age"
for FILE in clean autoremove; do apt -y -qq "${FILE}"; done         # Clean up      clean remove autoremove autoclean
export DEBIAN_FRONTEND=noninteractive
apt -qq update && APT_LISTCHANGES_FRONTEND=none apt -o Dpkg::Options::="--force-confnew" -y dist-upgrade --fix-missing 2>&1 \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2
#--- Cleaning up temp stuff
for FILE in clean autoremove; do apt -y -qq "${FILE}"; done         # Clean up - clean remove autoremove autoclean
#--- Check kernel stuff
_TMP=$(dpkg -l | grep linux-image- | grep -vc meta)
if [[ "${_TMP}" -gt 1 ]]; then
  echo -e "\n ${YELLOW}[i]${RESET} Detected ${YELLOW}multiple kernels${RESET}"
  TMP=$(dpkg -l | grep linux-image | grep -v meta | sort -t '.' -k 2 -g | tail -n 1 | grep "$(uname -r)")
  if [[ -z "${TMP}" ]]; then
    echo -e '\n '${RED}'[!]'${RESET}' You are '${RED}'not using the latest kernel'${RESET} 1>&2
    echo -e " ${YELLOW}[i]${RESET} You have it ${YELLOW}downloaded${RESET} & installed, just ${YELLOW}not USING IT${RESET}"
    sleep 30s
  else
    echo -e " ${YELLOW}[i]${RESET} ${YELLOW}You're using the latest kernel${RESET} (Good to continue)"
  fi
fi

##### Install kernel headers
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}kernel headers${RESET}"
apt -y -qq install make gcc "linux-headers-$(uname -r)" \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2
if [[ $? -ne 0 ]]; then
  echo -e ' '${RED}'[!]'${RESET}" There was an ${RED}issue installing kernel headers${RESET}" 1>&2
  echo -e " ${YELLOW}[i]${RESET} Are you ${YELLOW}USING${RESET} the ${YELLOW}latest kernel${RESET}?"
  echo -e " ${YELLOW}[i]${RESET} ${YELLOW}Reboot${RESET} your machine"
  #exit 1
  sleep 30s
fi

##### Install "kali full" meta packages (default tool selection)
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}kali-linux-full${RESET} meta-package"
echo -e " ${YELLOW}[i]${RESET}  ...this ${BOLD}may take a while${RESET} depending on your Kali version (e.g. ARM, light, mini or docker...)"
#--- Kali's default tools ~ https://www.kali.org/news/kali-linux-metapackages/
apt -y -qq install kali-linux-full \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2

##### Configure GRUB
echo -e "\n${GREEN}[+]${RESET} Configuring ${GREEN}GRUB${RESET} ~ boot manager"
grubTimeout=5
(dmidecode | grep -iq virtual) && grubTimeout=1   # Much less if we are in a VM
file=/etc/default/grub; [ -e "${file}" ] && cp -n $file{,.bkup}
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT='${grubTimeout}'/' "${file}"                           # Time out (lower if in a virtual machine, else possible dual booting)
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="vga=0x0318"/' "${file}"   # TTY resolution
update-grub

if [[ $(which gnome-shell) ]]; then
  ##### Configure GNOME 3
   echo -e "\n${GREEN}[+]${RESET}  Configuring ${GREEN}GNOME 3${RESET} ~ desktop environment"
  export DISPLAY=:0.0
  #-- Gnome Extension - Dash Dock (the toolbar with all the icons)
  gsettings set org.gnome.shell favorite-apps \
    "['gnome-terminal.desktop', 'org.gnome.Nautilus.desktop', 'kali-wireshark.desktop', 'firefox-esr.desktop', 'kali-burpsuite.desktop', 'kali-msfconsole.desktop', 'gedit.desktop']"
  #-- Gnome Extension - Alternate-tab (So it doesn't group the same windows up)
  GNOME_EXTENSIONS=$(gsettings get org.gnome.shell enabled-extensions | sed 's_^.\(.*\).$_\1_')
  echo "${GNOME_EXTENSIONS}" | grep -q "alternate-tab@gnome-shell-extensions.gcampax.github.com" \
    || gsettings set org.gnome.shell enabled-extensions "[${GNOME_EXTENSIONS}, 'alternate-tab@gnome-shell-extensions.gcampax.github.com']"
  #-- Gnome Extension - Drive Menu (Show USB devices in tray)
  GNOME_EXTENSIONS=$(gsettings get org.gnome.shell enabled-extensions | sed 's_^.\(.*\).$_\1_')
  echo "${GNOME_EXTENSIONS}" | grep -q "drive-menu@gnome-shell-extensions.gcampax.github.com" \
    || gsettings set org.gnome.shell enabled-extensions "[${GNOME_EXTENSIONS}, 'drive-menu@gnome-shell-extensions.gcampax.github.com']"
  #--- Workspaces
  gsettings set org.gnome.shell.overrides dynamic-workspaces false                         # Static
  gsettings set org.gnome.desktop.wm.preferences num-workspaces 3                          # Increase workspaces count to 3
  #--- Top bar
  gsettings set org.gnome.desktop.interface clock-show-date true                           # Show date next to time in the top tool bar
  #--- Hide desktop icon
  dconf write /org/gnome/nautilus/desktop/computer-icon-visible false
else
  echo -e "\n\n ${YELLOW}[i]${RESET} ${YELLOW}Skipping GNOME${RESET}..." 1>&2
fi

##### Configure GNOME terminal   Note: need to restart xserver for effect
echo -e "\n${GREEN}[+]${RESET} Configuring GNOME ${GREEN}terminal${RESET} ~ CLI interface"
gconftool-2 -t bool -s /apps/gnome-terminal/profiles/Default/scrollback_unlimited true
gconftool-2 -t string -s /apps/gnome-terminal/profiles/Default/background_type transparent
gconftool-2 -t string -s /apps/gnome-terminal/profiles/Default/background_darkness 0.85611499999999996


##### Configure GNOME terminal   Note: need to restart xserver for effect
 echo -e "\n${GREEN}[+]${RESET} Configuring GNOME ${GREEN}terminal${RESET} ~ CLI interface"
gconftool-2 -t bool -s /apps/gnome-terminal/profiles/Default/scrollback_unlimited true
gconftool-2 -t string -s /apps/gnome-terminal/profiles/Default/background_type transparent
gconftool-2 -t string -s /apps/gnome-terminal/profiles/Default/background_darkness 0.85611499999999996

##### Configure bash - all users
echo -e "\n${GREEN}[+]${RESET} Configuring ${GREEN}bash${RESET} ~ CLI shell"
file=/etc/bash.bashrc; [ -e "${file}" ] && cp -n $file{,.bkup}   #~/.bashrc
grep -q "cdspell" "${file}" \
  || echo "shopt -sq cdspell" >> "${file}"             # Spell check 'cd' commands
grep -q "autocd" "${file}" \
 || echo "shopt -s autocd" >> "${file}"                # So you don't have to 'cd' before a folder
grep -q "checkwinsize" "${file}" \
 || echo "shopt -sq checkwinsize" >> "${file}"         # Wrap lines correctly after resizing
grep -q "nocaseglob" "${file}" \
 || echo "shopt -sq nocaseglob" >> "${file}"           # Case insensitive pathname expansion
grep -q "HISTSIZE" "${file}" \
 || echo "HISTSIZE=10000" >> "${file}"                 # Bash history (memory scroll back)
grep -q "HISTFILESIZE" "${file}" \
 || echo "HISTFILESIZE=10000" >> "${file}"             # Bash history (file .bash_history)
#--- Apply new configs
source "${file}" || source ~/.zshrc

##### Install bash completion - all users
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}bash completion${RESET} ~ tab complete CLI commands"
apt -y -qq install bash-completion \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2
file=/etc/bash.bashrc; [ -e "${file}" ] && cp -n $file{,.bkup}   #~/.bashrc
sed -i '/# enable bash completion in/,+7{/enable bash completion/!s/^#//}' "${file}"
#--- Apply new configs
source "${file}" || source ~/.zshrc

##### Install bash colour - all users
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}bash colour${RESET} ~ colours shell output"
file=/etc/bash.bashrc; [ -e "${file}" ] && cp -n $file{,.bkup}   #~/.bashrc
([[ -e "${file}" && "$(tail -c 1 ${file})" != "" ]]) && echo >> "${file}"
sed -i 's/.*force_color_prompt=.*/force_color_prompt=yes/' "${file}"
grep -q '^force_color_prompt' "${file}" 2>/dev/null \
  || echo 'force_color_prompt=yes' >> "${file}"
sed -i 's#PS1='"'"'.*'"'"'#PS1='"'"'${debian_chroot:+($debian_chroot)}\\[\\033\[01;31m\\]\\u@\\h\\\[\\033\[00m\\]:\\[\\033\[01;34m\\]\\w\\[\\033\[00m\\]\\$ '"'"'#' "${file}"
grep -q "^export LS_OPTIONS='--color=auto'" "${file}" 2>/dev/null \
  || echo "export LS_OPTIONS='--color=auto'" >> "${file}"
grep -q '^eval "$(dircolors)"' "${file}" 2>/dev/null \
  || echo 'eval "$(dircolors)"' >> "${file}"
grep -q "^alias ls='ls $LS_OPTIONS'" "${file}" 2>/dev/null \
  || echo "alias ls='ls $LS_OPTIONS'" >> "${file}"
grep -q "^alias sys_update='apt-get update -y && apt-get distupgrade -y && apt-get upgrade -y && apt-get autoremove -y && apt-get autoclean'" "${file}" 2>/dev/null \
  || echo "alias ls='apt-get update -y && apt-get distupgrade -y && apt-get upgrade -y && apt-get autoremove -y && apt-get autoclean'" >> "${file}"
grep -q "^alias ll='ls $LS_OPTIONS -l'" "${file}" 2>/dev/null \
  || echo "alias ll='ls $LS_OPTIONS -l'" >> "${file}"
grep -q "^alias l='ls $LS_OPTIONS -lA'" "${file}" 2>/dev/null \
  || echo "alias l='ls $LS_OPTIONS -lA'" >> "${file}"
#--- All other users that are made afterwards
file=/etc/skel/.bashrc   #; [ -e "${file}" ] && cp -n $file{,.bkup}
sed -i 's/.*force_color_prompt=.*/force_color_prompt=yes/' "${file}"
#--- Apply new configs
source "${file}" || source ~/.zshrc


#### Configure aliases - root user
echo -e "\n${GREEN}[+]${RESET} Configuring ${GREEN}aliases${RESET} ~ CLI shortcuts"
#--- Enable defaults - root user
for FILE in /etc/bash.bashrc ~/.bashrc ~/.bash_aliases; do    #/etc/profile /etc/bashrc /etc/bash_aliases /etc/bash.bash_aliases
  [[ ! -f "${FILE}" ]] \
    && continue
  cp -n $FILE{,.bkup}
  sed -i 's/#alias/alias/g' "${FILE}"
done
#--- General system ones
file=~/.bash_aliases; [ -e "${file}" ] && cp -n $file{,.bkup}   #/etc/bash.bash_aliases
([[ -e "${file}" && "$(tail -c 1 ${file})" != "" ]]) && echo >> "${file}"
grep -q '^## grep aliases' "${file}" 2>/dev/null \
  || echo -e '## grep aliases\nalias grep="grep --color=always"\nalias ngrep="grep -n"\n' >> "${file}"
grep -q '^alias egrep=' "${file}" 2>/dev/null \
  || echo -e 'alias egrep="egrep --color=auto"\n' >> "${file}"
grep -q '^alias fgrep=' "${file}" 2>/dev/null \
  || echo -e 'alias fgrep="fgrep --color=auto"\n' >> "${file}"
grep -q '^alias mkdir=' "${file}" 2>/dev/null \
  || echo -e 'alias mkdir="mkdir -pv"\n' >> "${file}"
#--- Add in ours (OS programs)
grep -q '^alias tmux' "${file}" 2>/dev/null \
  || echo -e '## tmux\nalias tmux="tmux attach || tmux new"\n' >> "${file}"    #alias tmux="tmux attach -t $HOST || tmux new -s $HOST"
grep -q '^alias pyserver=' "${file}" 2>/dev/null \
  || echo -e 'alias pyserver="python -m SimpleHTTPServer"\n' >> "${file}"

#--- Add in ours (shortcuts)
grep -q '^## Checksums' "${file}" 2>/dev/null \
  || echo -e '## Checksums\nalias sha1="openssl sha1"\nalias md5="openssl md5"\n' >> "${file}"
grep -q '^## Force create folders' "${file}" 2>/dev/null \
  || echo -e '## Force create folders\nalias mkdir="/bin/mkdir -pv"\n' >> "${file}"
grep -q '^## Get external IP address' "${file}" 2>/dev/null \
  || echo -e '## Get external IP address\nalias ipx="curl -s http://ipinfo.io/ip"\n' >> "${file}"
grep -q '^## DNS - External IP #1' "${file}" 2>/dev/null \
  || echo -e '## DNS - External IP #1\nalias dns1="dig +short @resolver1.opendns.com myip.opendns.com"\n' >> "${file}"
grep -q '^## DNS - External IP #2' "${file}" 2>/dev/null \
  || echo -e '## DNS - External IP #2\nalias dns2="dig +short @208.67.222.222 myip.opendns.com"\n' >> "${file}"
grep -q '^## DNS - Check' "${file}" 2>/dev/null \
  || echo -e '### DNS - Check ("#.abc" is Okay)\nalias dns3="dig +short @208.67.220.220 which.opendns.com txt"\n' >> "${file}"
grep -q '^## Directory navigation aliases' "${file}" 2>/dev/null \
  || echo -e '## Directory navigation aliases\nalias ..="cd .."\nalias ...="cd ../.."\nalias ....="cd ../../.."\nalias .....="cd ../../../.."\n' >> "${file}"
grep -q '^## Extract file' "${file}" 2>/dev/null \
  || cat <<EOF >> "${file}" \
	|| echo -e ' '${RED}'[!] Issue with writing file'${RESET} 1>&2
## Extract file, example. "ex package.tar.bz2"
ex() {
  if [[ -f \$1 ]]; then
    case \$1 in
      *.tar.bz2) tar xjf \$1 ;;
      *.tar.gz)  tar xzf \$1 ;;
      *.bz2)     bunzip2 \$1 ;;
      *.rar)     rar x \$1 ;;
      *.gz)      gunzip \$1  ;;
      *.tar)     tar xf \$1  ;;
      *.tbz2)    tar xjf \$1 ;;
      *.tgz)     tar xzf \$1 ;;
      *.zip)     unzip \$1 ;;
      *.Z)       uncompress \$1 ;;
      *.7z)      7z x \$1 ;;
      *)         echo \$1 cannot be extracted ;;
    esac
  else
    echo \$1 is not a valid file
  fi
}
EOF

#--- Add in tools
grep -q '^## nmap' "${file}" 2>/dev/null \
  || echo -e '## nmap\nalias nmap="nmap --reason --open --stats-every 3m --max-retries 1 --max-scan-delay 20 --defeat-rst-ratelimit"\n' >> "${file}"
grep -q '^## metasploit' "${file}" 2>/dev/null \
  || (echo -e '## metasploit\nalias msfc="systemctl start postgresql; msfdb start; msfconsole -q \"\$@\""' >> "${file}" \
    && echo -e 'alias msfconsole="systemctl start postgresql; msfdb start; msfconsole \"\$@\""\n' >> "${file}" )
#--- Apply new aliases
source "${file}"

##### Install (GNOME) Terminator
echo -e "\n${GREEN}[+]${RESET} Installing (GNOME) ${GREEN}Terminator${RESET} ~ multiple terminals in a single window"
apt -y -qq install terminator \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2
#--- Configure terminator
mkdir -p ~/.config/terminator/
file=~/.config/terminator/config; [ -e "${file}" ] && cp -n $file{,.bkup}
cat <<EOF > "${file}" \
  || echo -e ' '${RED}'[!] Issue with writing file'${RESET} 1>&2
[global_config]
  enabled_plugins = TerminalShot, LaunchpadCodeURLHandler, APTURLHandler, LaunchpadBugURLHandler
[keybindings]
[profiles]
  [[default]]
    background_darkness = 0.9
    scroll_on_output = False
    copy_on_selection = True
    background_type = transparent
    scrollback_infinite = True
    show_titlebar = False
[layouts]
  [[default]]
    [[[child1]]]
      type = Terminal
      parent = window0
    [[[window0]]]
      type = Window
      parent = ""
[plugins]
EOF

#### Install vim - all users
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}vim${RESET} ~ CLI text editor"
apt -y -qq install vim \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2
#--- Configure vim
file=/etc/vim/vimrc; [ -e "${file}" ] && cp -n $file{,.bkup}   #~/.vimrc
([[ -e "${file}" && "$(tail -c 1 ${file})" != "" ]]) && echo >> "${file}"
sed -i 's/.*syntax on/syntax on/' "${file}"
sed -i 's/.*set background=dark/set background=dark/' "${file}"
sed -i 's/.*set showcmd/set showcmd/' "${file}"
sed -i 's/.*set showmatch/set showmatch/' "${file}"
sed -i 's/.*set ignorecase/set ignorecase/' "${file}"
sed -i 's/.*set smartcase/set smartcase/' "${file}"
sed -i 's/.*set incsearch/set incsearch/' "${file}"
sed -i 's/.*set autowrite/set autowrite/' "${file}"
sed -i 's/.*set hidden/set hidden/' "${file}"
sed -i 's/.*set mouse=.*/"set mouse=a/' "${file}"
grep -q '^set number' "${file}" 2>/dev/null \
  || echo 'set number' >> "${file}"                                                                      # Add line numbers
grep -q '^set expandtab' "${file}" 2>/dev/null \
  || echo -e 'set expandtab\nset smarttab' >> "${file}"                                                  # Set use spaces instead of tabs
grep -q '^set softtabstop' "${file}" 2>/dev/null \
  || echo -e 'set softtabstop=4\nset shiftwidth=4' >> "${file}"                                          # Set 4 spaces as a 'tab'
grep -q '^set foldmethod=marker' "${file}" 2>/dev/null \
  || echo 'set foldmethod=marker' >> "${file}"                                                           # Folding
grep -q '^nnoremap <space> za' "${file}" 2>/dev/null \
  || echo 'nnoremap <space> za' >> "${file}"                                                             # Space toggle folds
grep -q '^set hlsearch' "${file}" 2>/dev/null \
  || echo 'set hlsearch' >> "${file}"                                                                    # Highlight search results
grep -q '^set laststatus' "${file}" 2>/dev/null \
  || echo -e 'set laststatus=2\nset statusline=%F%m%r%h%w\ (%{&ff}){%Y}\ [%l,%v][%p%%]' >> "${file}"     # Status bar
grep -q '^filetype on' "${file}" 2>/dev/null \
  || echo -e 'filetype on\nfiletype plugin on\nsyntax enable\nset grepprg=grep\ -nH\ $*' >> "${file}"    # Syntax highlighting
grep -q '^set wildmenu' "${file}" 2>/dev/null \
  || echo -e 'set wildmenu\nset wildmode=list:longest,full' >> "${file}"                                 # Tab completion
grep -q '^set invnumber' "${file}" 2>/dev/null \
  || echo -e ':nmap <F8> :set invnumber<CR>' >> "${file}"                                                # Toggle line numbers
grep -q '^set pastetoggle=<F9>' "${file}" 2>/dev/null \
  || echo -e 'set pastetoggle=<F9>' >> "${file}"                                                         # Hotkey - turning off auto indent when pasting
grep -q '^:command Q q' "${file}" 2>/dev/null \
  || echo -e ':command Q q' >> "${file}"     

##### Install git - all users
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}git${RESET} ~ revision control"
apt -y -qq install git \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2
#--- Set as default editor
git config --global core.editor "vim"
#--- Set as default mergetool
git config --global merge.tool vimdiff
git config --global merge.conflictstyle diff3
git config --global mergetool.prompt false
#--- Set as default push
git config --global push.default simple

#Fix stupid typo I always make
#--- Set as default editor
export EDITOR="vim"   #update-alternatives --config editor
file=/etc/bash.bashrc; [ -e "${file}" ] && cp -n $file{,.bkup}
([[ -e "${file}" && "$(tail -c 1 ${file})" != "" ]]) && echo >> "${file}"
grep -q '^EDITOR' "${file}" 2>/dev/null \
  || echo 'EDITOR="vim"' >> "${file}"
git config --global core.editor "vim"
#--- Set as default mergetool
git config --global merge.tool vimdiff
git config --global merge.conflictstyle diff3
git config --global mergetool.prompt false

##### Setup firefox
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}firefox${RESET} ~ GUI web browser"
apt -y -qq install unzip curl firefox-esr \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2
#--- Configure firefox
export DISPLAY=:0.0
timeout 15 firefox >/dev/null 2>&1                # Start and kill. Files needed for first time run
timeout 5 killall -9 -q -w firefox-esr >/dev/null
file=$(find ~/.mozilla/firefox/*.default*/ -maxdepth 1 -type f -name 'prefs.js' -print -quit)
[ -e "${file}" ] \
  && cp -n $file{,.bkup}   #/etc/firefox-esr/pref/*.js
([[ -e "${file}" && "$(tail -c 1 ${file})" != "" ]]) && echo >> "${file}"
sed -i 's/^.network.proxy.socks_remote_dns.*/user_pref("network.proxy.socks_remote_dns", true);' "${file}" 2>/dev/null \
  || echo 'user_pref("network.proxy.socks_remote_dns", true);' >> "${file}"
sed -i 's/^.browser.safebrowsing.enabled.*/user_pref("browser.safebrowsing.enabled", false);' "${file}" 2>/dev/null \
  || echo 'user_pref("browser.safebrowsing.enabled", false);' >> "${file}"
sed -i 's/^.browser.safebrowsing.malware.enabled.*/user_pref("browser.safebrowsing.malware.enabled", false);' "${file}" 2>/dev/null \
  || echo 'user_pref("browser.safebrowsing.malware.enabled", false);' >> "${file}"
sed -i 's/^.browser.safebrowsing.remoteLookups.enabled.*/user_pref("browser.safebrowsing.remoteLookups.enabled", false);' "${file}" 2>/dev/null \
  || echo 'user_pref("browser.safebrowsing.remoteLookups.enabled", false);' >> "${file}"
sed -i 's/^.*browser.startup.page.*/user_pref("browser.startup.page", 0);' "${file}" 2>/dev/null \
  || echo 'user_pref("browser.startup.page", 0);' >> "${file}"
sed -i 's/^.*privacy.donottrackheader.enabled.*/user_pref("privacy.donottrackheader.enabled", true);' "${file}" 2>/dev/null \
  || echo 'user_pref("privacy.donottrackheader.enabled", true);' >> "${file}"
sed -i 's/^.*browser.showQuitWarning.*/user_pref("browser.showQuitWarning", true);' "${file}" 2>/dev/null \
  || echo 'user_pref("browser.showQuitWarning", true);' >> "${file}"
sed -i 's/^.*extensions.https_everywhere._observatory.popup_shown.*/user_pref("extensions.https_everywhere._observatory.popup_shown", true);' "${file}" 2>/dev/null \
  || echo 'user_pref("extensions.https_everywhere._observatory.popup_shown", true);' >> "${file}"
sed -i 's/^.network.security.ports.banned.override/user_pref("network.security.ports.banned.override", "1-65455");' "${file}" 2>/dev/null \
  || echo 'user_pref("network.security.ports.banned.override", "1-65455");' >> "${file}"
#--- Replace bookmarks (base: http://pentest-bookmarks.googlecode.com)
file=$(find ~/.mozilla/firefox/*.default*/ -maxdepth 1 -type f -name 'bookmarks.html' -print -quit)
[ -e "${file}" ] \
  && cp -n $file{,.bkup}   #/etc/firefox-esr/profile/bookmarks.html
#--- Configure bookmarks
sed -i 's#^</DL><p>#        </DL><p>\n    </DL><p>\n</DL><p>#' "${file}"                                          # Fix import issues from pentest-bookmarks...
sed -i 's#^    <DL><p>#    <DL><p>\n    <DT><A HREF="http://127.0.0.1/">localhost</A>#' "${file}"                 # Add localhost to bookmark toolbar (before hackery folder)
sed -i 's#^</DL><p>#    <DT><A HREF="http://127.0.0.1:3000/ui/panel">BeEF</A>\n</DL><p>#' "${file}"               # Add BeEF UI to bookmark toolbar
sed -i 's#^</DL><p>#    <DT><A HREF="http://127.0.0.1/rips/">RIPS</A>\n</DL><p>#' "${file}"                       # Add RIPs to bookmark toolbar
sed -i 's#^</DL><p>#    <DT><A HREF="https://paulschou.com/tools/xlate/">XLATE</A>\n</DL><p>#' "${file}"          # Add XLATE to bookmark toolbar
sed -i 's#^</DL><p>#    <DT><A HREF="https://hackvertor.co.uk/public">HackVertor</A>\n</DL><p>#' "${file}"        # Add HackVertor to bookmark toolbar
sed -i 's#^</DL><p>#    <DT><A HREF="http://www.irongeek.com/skiddypad.php">SkiddyPad</A>\n</DL><p>#' "${file}"   # Add Skiddypad to bookmark toolbar
sed -i 's#^</DL><p>#    <DT><A HREF="https://www.exploit-db.com/search/">Exploit-DB</A>\n</DL><p>#' "${file}"     # Add Exploit-DB to bookmark toolbar
sed -i 's#^</DL><p>#    <DT><A HREF="http://offset-db.com/">Offset-DB</A>\n</DL><p>#' "${file}"                   # Add Offset-DB to bookmark toolbar
sed -i 's#^</DL><p>#    <DT><A HREF="http://shell-storm.org/shellcode/">Shelcodes</A>\n</DL><p>#' "${file}"       # Add Shelcodes to bookmark toolbar
sed -i 's#^</DL><p>#    <DT><A HREF="http://ropshell.com/">ROP Shell</A>\n</DL><p>#' "${file}"                    # Add ROP Shell to bookmark toolbar
sed -i 's#^</DL><p>#    <DT><A HREF="https://ifconfig.io/">ifconfig</A>\n</DL><p>#' "${file}"                     # Add ifconfig.io to bookmark toolbar
sed -i 's#^</DL><p>#    <DT><A HREF="https://pentestmonkey.net/">PentestMonkey</A>\n</DL><p>#' "${file}"          # Add PentestMonkey to bookmark $
sed -i 's#^</DL><p>#    <DT><A HREF="https://howucan.gr/">Howucan</A>\n</DL><p>#' "${file}"          # Add howucan.gr
sed -i 's#^</DL><p>#    <DT><A HREF="https://crt.sh/">crt.sh</A>\n</DL><p>#' "${file}"          # Add crt.sh

sed -i 's#<HR>#<DT><H3 ADD_DATE="1303667175" LAST_MODIFIED="1303667175" PERSONAL_TOOLBAR_FOLDER="true">Bookmarks Toolbar</H3>\n<DD>Add bookmarks to this folder to see them displayed on the Bookmarks Toolbar#' "${file}"
#--- Clear bookmark cache
find ~/.mozilla/firefox/*.default*/ -maxdepth 1 -mindepth 1 -type f -name "places.sqlite" -delete
find ~/.mozilla/firefox/*.default*/bookmarkbackups/ -type f -delete

##### Install metasploit ~ http://docs.kali.org/general-use/starting-metasploit-framework-in-kali
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}metasploit${RESET} ~ exploit framework"
apt -y -qq install metasploit-framework \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2
mkdir -p ~/.msf4/modules/{auxiliary,exploits,payloads,post}/
#--- Fix any port issues
file=$(find /etc/postgresql/*/main/ -maxdepth 1 -type f -name postgresql.conf -print -quit);
[ -e "${file}" ] && cp -n $file{,.bkup}
sed -i 's/port = .* #/port = 5432 /' "${file}"
#--- Fix permissions - 'could not translate host name "localhost", service "5432" to address: Name or service not known'
chmod 0644 /etc/hosts
#--- Start services
systemctl stop postgresql
systemctl start postgresql
msfdb reinit
sleep 5s
#--- Autorun Metasploit commands each startup
file=~/.msf4/msf_autorunscript.rc; [ -e "${file}" ] && cp -n $file{,.bkup}
if [[ -f "${file}" ]]; then
  echo -e ' '${RED}'[!]'${RESET}" ${file} detected. Skipping..." 1>&2
else
  cat <<EOF > "${file}"
#run post/windows/escalate/getsystem
#run migrate -f -k
#run migrate -n "explorer.exe" -k    # Can trigger AV alerts by touching explorer.exe...
#run post/windows/manage/smart_migrate
#run post/windows/gather/smart_hashdump
EOF
fi
file=~/.msf4/msfconsole.rc; [ -e "${file}" ] && cp -n $file{,.bkup}
if [[ -f "${file}" ]]; then
  echo -e ' '${RED}'[!]'${RESET}" ${file} detected. Skipping..." 1>&2
else
  cat <<EOF > "${file}"
load auto_add_route
load alias
alias del rm
alias handler use exploit/multi/handler
load sounds
setg TimestampOutput true
setg VERBOSE true
setg ExitOnSession false
setg EnableStageEncoding true
setg LHOST 0.0.0.0
setg LPORT 443
EOF
#use exploit/multi/handler
#setg AutoRunScript 'multi_console_command -rc "~/.msf4/msf_autorunscript.rc"'
#set PAYLOAD windows/meterpreter/reverse_https
fi
#--- Aliases time
file=~/.bash_aliases; [ -e "${file}" ] && cp -n $file{,.bkup}   #/etc/bash.bash_aliases
([[ -e "${file}" && "$(tail -c 1 ${file})" != "" ]]) && echo >> "${file}"
#--- Aliases for console
grep -q '^alias msfc=' "${file}" 2>/dev/null \
  || echo -e 'alias msfc="systemctl start postgresql; msfdb start; msfconsole -q \"\$@\""' >> "${file}"
grep -q '^alias msfconsole=' "${file}" 2>/dev/null \
  || echo -e 'alias msfconsole="systemctl start postgresql; msfdb start; msfconsole \"\$@\""\n' >> "${file}"
#--- Aliases to speed up msfvenom (create static output)
grep -q "^alias msfvenom-list-all" "${file}" 2>/dev/null \
  || echo "alias msfvenom-list-all='cat ~/.msf4/msfvenom/all'" >> "${file}"
grep -q "^alias msfvenom-list-nops" "${file}" 2>/dev/null \
  || echo "alias msfvenom-list-nops='cat ~/.msf4/msfvenom/nops'" >> "${file}"
grep -q "^alias msfvenom-list-payloads" "${file}" 2>/dev/null \
  || echo "alias msfvenom-list-payloads='cat ~/.msf4/msfvenom/payloads'" >> "${file}"
grep -q "^alias msfvenom-list-encoders" "${file}" 2>/dev/null \
  || echo "alias msfvenom-list-encoders='cat ~/.msf4/msfvenom/encoders'" >> "${file}"
grep -q "^alias msfvenom-list-formats" "${file}" 2>/dev/null \
  || echo "alias msfvenom-list-formats='cat ~/.msf4/msfvenom/formats'" >> "${file}"
grep -q "^alias msfvenom-list-generate" "${file}" 2>/dev/null \
  || echo "alias msfvenom-list-generate='_msfvenom-list-generate'" >> "${file}"
grep -q "^function _msfvenom-list-generate" "${file}" 2>/dev/null \
  || cat <<EOF >> "${file}" \
    || echo -e ' '${RED}'[!] Issue with writing file'${RESET} 1>&2
function _msfvenom-list-generate {
  mkdir -p ~/.msf4/msfvenom/
  msfvenom --list > ~/.msf4/msfvenom/all
  msfvenom --list nops > ~/.msf4/msfvenom/nops
  msfvenom --list payloads > ~/.msf4/msfvenom/payloads
  msfvenom --list encoders > ~/.msf4/msfvenom/encoders
  msfvenom --help-formats 2> ~/.msf4/msfvenom/formats
}
EOF
#--- Apply new aliases
source "${file}" || source ~/.zshrc
#--- Generate (Can't call alias)
mkdir -p ~/.msf4/msfvenom/
msfvenom --list > ~/.msf4/msfvenom/all
msfvenom --list nops > ~/.msf4/msfvenom/nops
msfvenom --list payloads > ~/.msf4/msfvenom/payloads
msfvenom --list encoders > ~/.msf4/msfvenom/encoders
msfvenom --help-formats 2> ~/.msf4/msfvenom/formats
#--- First time run with Metasploit
echo -e " ${GREEN}[i]${RESET}  ${GREEN}Starting Metasploit for the first time${RESET} ~ this ${BOLD}will take a ~350 seconds${RESET} (~6 mintues)"
echo "Started at: $(date)"
systemctl start postgresql
msfdb start
msfconsole -q -x 'version;db_status;sleep 310;exit'

##### Configure python console - all users
echo -e "\n${GREEN}[+]${RESET} Configuring ${GREEN}python console${RESET} ~ tab complete & history support"
export PYTHONSTARTUP=$HOME/.pythonstartup
file=/etc/bash.bashrc; [ -e "${file}" ] && cp -n $file{,.bkup}   #~/.bashrc
grep -q PYTHONSTARTUP "${file}" \
  || echo 'export PYTHONSTARTUP=$HOME/.pythonstartup' >> "${file}"
#--- Python start up file
cat <<EOF > ~/.pythonstartup \
  || echo -e ' '${RED}'[!] Issue with writing file'${RESET} 1>&2
import readline
import rlcompleter
import atexit
import os
## Tab completion
readline.parse_and_bind('tab: complete')
## History file
histfile = os.path.join(os.environ['HOME'], '.pythonhistory')
try:
    readline.read_history_file(histfile)
except IOError:
    pass
atexit.register(readline.write_history_file, histfile)
## Quit
del os, histfile, readline, rlcompleter
EOF
#--- Apply new configs
source "${file}" || source ~/.zshrc


##### Install virtualenvwrapper
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}virtualenvwrapper${RESET} ~ virtual environment wrapper"
apt -y -qq install virtualenvwrapper \
|| echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2

##### Install vulscan script for nmap
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}vulscan script for nmap${RESET} ~ vulnerability scanner add-on"
apt -y -qq install nmap curl \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2
mkdir -p /usr/share/nmap/scripts/vulscan/
timeout 300 curl --progress -k -L -f "http://www.computec.ch/projekte/vulscan/download/nmap_nse_vulscan-2.0.tar.gz" > /tmp/nmap_nse_vulscan.tar.gz \
  || echo -e ' '${RED}'[!]'${RESET}" Issue downloading file" 1>&2      #***!!! hardcoded version! Need to manually check for updates
gunzip /tmp/nmap_nse_vulscan.tar.gz
tar -xf /tmp/nmap_nse_vulscan.tar -C /usr/share/nmap/scripts/
#--- Fix permissions (by default its 0777)
chmod -R 0755 /usr/share/nmap/scripts/; find /usr/share/nmap/scripts/ -type f -exec chmod 0644 {} \;

##### Install httptunnel
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}httptunnel${RESET} ~ Tunnels data streams in HTTP requests"
apt -y -qq install http-tunnel \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2

##### Install sshuttle
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}sshuttle${RESET} ~ VPN over SSH"
apt -y -qq install sshuttle \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2
#--- Example
#sshuttle --dns --remote root@123.9.9.9 0/0 -vv

##### Install gobuster
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}gobuster${RESET} ~ Directory/file % DNS busting tool written in Go"
apt -y -qq install http-tunnel \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2

###Python Dependencies
apt -y -qq install python2.7 python-pip python-dev git libssl-dev libffi-dev build-essential wine32

##### GitHub Repositories 

##### Install exiftool
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}exiftool${RESET} ~ Exiftool Metadata Information"
wget http://www.sno.phy.queensu.ca/~phil/exiftool/Image-ExifTool-10.53.tar.gz
gzip -dc Image-ExifTool-10.53.tar.gz | tar -xf -
rm Image-ExifTool-10.53.tar.gz
cd Image-ExifTool-10.53
perl Makefile.PL
make test
make install

##### Install PEDA
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}PEDA${RESET}"
git clone https://github.com/longld/peda.git ~/peda
echo "source ~/peda/peda.py" >> ~/.gdbinit

##### Install dirsearch
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}dirsearch${RESET}"
git clone https://github.com/maurosoria/dirsearch.git /opt/dirsearch

##### Install CTF-Tools
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}CTF-Tools${RESET}"
git clone https://github.com/zardus/ctf-tools /opt/ctf-tools

##### Install GitTools
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}GitTools${RESET}"
git clone https://github.com/internetwache/GitTools /opt/gittools

##### Install mimipenguin
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}mimipenguin${RESET}"
git clone https://github.com/huntergregal/mimipenguin /opt/mimipenguin

##### Install routersploit
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}routersploit${RESET}"
git clone https://github.com/reverse-shell/routersploit /opt/routersploit
pip install -r /opt/routersploit/requirements.txt

##### Install clusterd
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}clusterd${RESET}"
git clone https://github.com/hatRiot/clusterd.git /opt/clusterd
pip install -r /opt/clusterd/requirements.txt

##### Install jexboss
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}jexboss${RESET}"
git clone https://github.com/joaomatosf/jexboss /opt/jexboss
pip install -r /opt/jexboss/requires.txt

##### Install punter
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}punter${RESET}"
git clone https://github.com/nethunteros/punter /opt/punter
pip install -r /opt/punter/requirements.txt

#### Instal pwntools
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}pwn-tools${RESET}"
pip install --upgrade pip
pip install --upgrade pwntools

##### Install ltrace
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}ltrace${RESET} ~ Linux debugging tool"
apt -y -qq install ltrace \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2


##### Install gcc & multilib
echo -e "\n${GREEN}[+]${RESET} Installing ${GREEN}gcc${RESET} & ${GREEN}multilibc${RESET} ~ compiling libraries"
for FILE in cc gcc g++ gcc-multilib make automake lsibc6 libc6-dev libc6-amd64 libc6-dev-amd64 libc6-i386 libc6-dev-i386 libc6-i686 libc6-dev-i686 dpkg-dev; do
  apt -y -qq install "${FILE}" 2>/dev/null
done

##### Install apache2 & php
echo -e "\n${GREEN}[+]${RESET}  Installing ${GREEN}apache2${RESET} & ${GREEN}php${RESET} ~ web server"
apt -y -qq install apache2 php php-cli php-curl \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2
touch /var/www/html/favicon.ico
grep -q '<title>Apache2 Debian Default Page: It works</title>' /var/www/html/index.html 2>/dev/null \
  && rm -f /var/www/html/index.html \
  && echo '<?php echo "Access denied for " . $_SERVER["REMOTE_ADDR"]; ?>' > /var/www/html/index.php \
  && echo -e 'User-agent: *n\Disallow: /\n' > /var/www/html/robots.txt
#--- Setup alias
file=~/.bash_aliases; [ -e "${file}" ] && cp -n $file{,.bkup}   #/etc/bash.bash_aliases
([[ -e "${file}" && "$(tail -c 1 ${file})" != "" ]]) && echo >> "${file}"
grep -q '^## www' "${file}" 2>/dev/null \
  || echo -e '## www\nalias wwwroot="cd /var/www/html/"\n' >> "${file}"
#--- Apply new alias
source "${file}"

##### Setup SSH
echo -e "\n${GREEN}[+]${RESET} Setting up ${GREEN}SSH${RESET} ~ CLI access"
apt -y -qq install openssh-server \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2
#--- Wipe current keys
rm -f /etc/ssh/ssh_host_*
find ~/.ssh/ -type f ! -name authorized_keys -delete 2>/dev/null
#--- Generate new keys
ssh-keygen -b 4096 -t rsa1 -f /etc/ssh/ssh_host_key -P "" >/dev/null
ssh-keygen -b 4096 -t rsa -f /etc/ssh/ssh_host_rsa_key -P "" >/dev/null
ssh-keygen -b 1024 -t dsa -f /etc/ssh/ssh_host_dsa_key -P "" >/dev/null
ssh-keygen -b 521 -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -P "" >/dev/null
ssh-keygen -b 4096 -t rsa -f ~/.ssh/id_rsa -P "" >/dev/null
#--- Change MOTD
apt -y -qq install cowsay \
  || echo -e ' '${RED}'[!] Issue with apt install'${RESET} 1>&2
echo "Moo" | /usr/games/cowsay > /etc/motd
#--- Change SSH settings
file=/etc/ssh/sshd_config; [ -e "${file}" ] && cp -n $file{,.bkup}
sed -i 's/^PermitRootLogin .*/PermitRootLogin yes/g' "${file}"      # Accept password login (overwrite Debian 8+'s more secure default option...)
sed -i 's/^#AuthorizedKeysFile /AuthorizedKeysFile /g' "${file}"    # Allow for key based login
#--- Enable ssh at startup
systemctl enable ssh
#--- Setup alias (handy for 'zsh: correct 'ssh' to '.ssh' [nyae]? n')
file=~/.bash_aliases; [ -e "${file}" ] && cp -n $file{,.bkup}   #/etc/bash.bash_aliases
([[ -e "${file}" && "$(tail -c 1 ${file})" != "" ]]) && echo >> "${file}"
grep -q '^## ssh' "${file}" 2>/dev/null \
  || echo -e '## ssh\nalias ssh-start="systemctl restart ssh"\nalias ssh-stop="systemctl stop ssh"\n' >> "${file}"
#--- Apply new alias
source "${file}"

#### Clean the system
echo -e "\n${GREEN}[+]${RESET} ${GREEN}Cleaning${RESET} the system"
#--- Clean package manager
for FILE in clean autoremove; do apt -y -qq "${FILE}"; done
apt -y -qq purge $(dpkg -l | tail -n +6 | egrep -v '^(h|i)i' | awk '{print $2}')   # Purged packages
#--- Update slocate database
updatedb
#--- Empty every trashes
rm -rf /home/*/.local/share/Trash/*/** &> /dev/null
rm -rf /root/.local/share/Trash/*/** &> /dev/null
#--- Reset folder location
cd ~/ &>/dev/null
#--- Remove any history files (as they could contain sensitive info)
history -cw 2>/dev/null
for i in $(cut -d: -f6 /etc/passwd | sort -u); do
  [ -e "${i}" ] && find "${i}" -type f -name '.*_history' -delete
done
