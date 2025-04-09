#!/bin/zsh

function git-acc(){
  local function Echo_Color(){
    case $1 in
      r* | R* )
      COLOR='\e[31m'
      ;;
      g* | G* )
      COLOR='\e[32m'
      ;;
      y* | Y* )
      COLOR='\e[33m'
      ;;
      b* | B* )
      COLOR='\e[34m'
      ;;
      *)
      echo "$COLOR Wrong COLOR keyword!\e[0m" 
      ;;
    esac
    echo -e "$COLOR$2\e[0m"
  }

  local function Ask_yn(){
      printf "\e[33m$1\e[0m\e[33m [y/n] \e[0m"
      read respond
      if [ "$respond" = "y" -o "$respond" = "Y" ]; then
          return 1
      elif [ "$respond" = "n" -o "$respond" = "N" ]; then
          return 0
      else
          Echo_Color r 'wrong command!!'
          Ask_yn $1
          return $?
      fi
      unset respond
  }

  local function list_accounts() {
      if [ -f "$gitacc_locate" ]; then
          Echo_Color g "List of added Git accounts:"
          cat "$gitacc_locate" | awk '
              /\[.*\]/ { 
                  if (acc_name != "") {
                      print ""  # Add a blank line between accounts
                  }
                  acc_name = substr($0, 2, length($0) - 2); 
                  printf "Account: %s\n", acc_name; 
              } 
              /name =/ { printf "  Name: %s\n", $3; }
              /email =/ { printf "  Email: %s\n", $3; }
              /private_key =/ { printf "  Private Key: %s\n", $3; }
              /public_key =/ { printf "  Public Key: %s\n", $3; }
              END { if (acc_name != "") print "" }  # Add a final blank line if there are accounts
          '
      else
          Echo_Color r "No Git accounts have been added yet."
      fi
  }

  local function show_script_help(){
      local help='
          +---------------+
          |    git-acc    |
          +---------------+

  SYNOPSIS

    git-acc [account]|[option]

  OPTIONS

    [account]               use which accounts on this shell, type the account name that you register.
    -h, --help              print help information.
    -l, --list              list all added Git accounts.
    -add, --add_account     build git_account info. & ssh-key.
        -t, --type          ssh-key types, follow `ssh-keygen` rule, 
                            types: dsa | ecdsa | ecdsa-sk | ed25519 | ed25519-sk | rsa(default)
    -rm, --remove_account   remove git_account info. & ssh-key from this device
    -out, --logout          logout your current ssh-acc.

  EXAMPLES

    $ git-acc tw-yshuang
    $ git-acc --list
  '
      echo $help
  }

  local function _acc(){
    local users_info=$(cat "$gitacc_locate" | grep -n '\[.*\]')
    accs_line=($(echo $users_info | cut -f1 -d ':'))
    accnames=($(echo $users_info | cut -d '[' -f2 | cut -d ']' -f1))
    unset users_info
  }

  local ssh_key_locate="$HOME/.ssh/id_"  # "./id_rsa_"
  local gitacc_locate="$HOME/.gitacc" # "./.gitacc"
  local ssh_keygen_type="rsa"
  local GIT_ACC_ARG=()
  local GIT_ACC=()    # git account to 
  local user_name
  local user_mail
  local key_type
  local accs_line=()  # all the user's tag line that is in the $gitacc_locate
  local accnames=()   # all the accnames that is in the $gitacc_locate
  local overWrite=0   # is recover old ssh-key
  local acc_info=()   # single account info, ([tag] name mail private_key publish_key)

  # List accounts if no arguments are given
  if [ "$#" -eq 0 ]; then
    list_accounts
    return 1
  fi
  
  while [ "$#" -gt 0 ]; do
    case "$1" in
      # Help
      '-h'|'--help')
        show_script_help
        unset -f show_script_help
        return 1
      ;;
      # List accounts
      '-l'|'--list')
        list_accounts
        return 1
      ;;
      # build git_account info. & ssh-key.
      '-add'|'--add_account')
        GIT_ACC_ARG+='add'
        shift 1
      ;;
      # ssh-key type
      '-t'|'--type')
        ssh_keygen_type=$2
        shift 2
      ;;
      # remove git_account info. & ssh-key from this device
      '-rm'|'--remove_account')
        GIT_ACC_ARG+='rm'
        shift 1
      ;;
      '-out'|'--logout')
        ssh-agent -k
        unset SSH_AUTH_SOCK SSH_AGENT_PID
        git config --global --unset user.name
        git config --global --unset user.email
        shift 1
      ;;
      # use which account to access.
      * )
        GIT_ACC+=$1
        shift 1
      ;;
    esac
  done

  if [ "${#GIT_ACC_ARG[*]}" -gt 1 ] || [ "${#GIT_ACC_ARG[*]}" -ge 1 -a "${#GIT_ACC[*]}" -ge 1 ]; then
    Echo_Color r 'Wrong: Mutiple Parameters!!\n' # too many input args or accounts 
    return
  else
    case "${GIT_ACC_ARG[*]}" in
      'add')
        printf "Enter your git user name: "; read user_name
        printf "Enter your git user mail: "; read user_mail

        _acc # read accounts info.
        for acc_name in ${accnames[*]}; do
          if [ "$acc_name" = "$user_name" ]; then # if is not the match account_name
            Echo_Color r "Warning: Already have same account name."
            Ask_yn "Do you want to overwrite?"; overWrite=$?
            if [ $overWrite = 0 ]; then
              Echo_Color y "Please use another account name."
              return
            fi
          fi
        done

        ssh_key_locate="$ssh_key_locate${ssh_keygen_type}_"
        ssh-keygen -t $ssh_keygen_type -C "$user_mail" -f "$ssh_key_locate$user_name"
        if [ $overWrite = 0 ]; then # if recover is not happen, then write it to the $gitacc_locate, else nothing change.
          echo "[$user_name]\n\tname = $user_name\n\temail = $user_mail\n\tprivate_key = $ssh_key_locate$user_name\n\tpublic_key = $ssh_key_locate$user_name.pub" >> "$gitacc_locate"
        fi

        Echo_Color g "Your SSH publish key is :"
        cat "$ssh_key_locate$user_name.pub"
        Echo_Color g "Paste it to your SSH keys in github or server."
      ;;
      'rm')
        printf "Enter the git user name you want to remove: "; read user_name
        
        _acc # read accounts info.
        local i=1 # index of users array
        for acc_name in ${accnames[*]}; do
          if [ "$acc_name" != "$user_name" ]; then # if is not the match account_name
            i=$(( $i + 1))

            if [ "$i" -gt "${#accs_line[*]}" ]; then # if there isn't a match account_name 
              Echo_Color r "Wrong: account name!!"
              return
            fi
          else
            if [ "$i" = "${#accs_line[*]}" ]; then # is the last account in $gitacc_locate
              acc_info=($(sed -n "${accs_line[$i]}, $ p" $gitacc_locate | cut -f2 -d"="))
              vi +"${accs_line[$i]}, $ d" +wq $gitacc_locate
            else
              acc_info=($(sed -n "${accs_line[$i]}, $((${accs_line[$(($i + 1))]} - 1)) p" $gitacc_locate | cut -f2 -d"="))
              vi +"${accs_line[$i]}, $((${accs_line[$(($i + 1))]} - 1)) d" +wq $gitacc_locate
            fi
              rm -rf "${acc_info[-2]}" "${acc_info[-1]}" # remove ssh private & publish keys
          fi
        done
      ;;
    esac
  fi

  if [ "${#GIT_ACC[*]}" -gt 1 ]; then
    Echo_Color r 'Wrong: Mutiple Parameters!!\n' # too many input args or accounts 
  elif [ "${#GIT_ACC[*]}" = 1 ]; then
    _acc # read accounts info.
    local i=1 # index of users array
    for acc_name in ${accnames[*]}; do
      if [ "$acc_name" != "${GIT_ACC[1]}" ]; then # if is not the match account_name
        i=$(($i + 1))

        if [ "$i" -gt "${#accs_line[*]}" ]; then # if there isn't a match account_name 
          Echo_Color r "Wrong: account name!!"
          break
        fi
      else
        if [ "$i" = "${#accs_line[*]}" ]; then # is the last account in $gitacc_locate
          acc_info=($(sed -n "${accs_line[$i]}, $ p" $gitacc_locate | cut -f2 -d"="))
        else
          acc_info=($(sed -n "${accs_line[$i]}, $((${accs_line[$(($i + 1))]} - 1)) p" $gitacc_locate | cut -f2 -d"="))
        fi

        if [ "$(echo "$SSH_AUTH_SOCK" | grep 'agent')" != "" ]; then
          Ask_yn "You already have active git-agent on this shell, you want to overwrite it?"; overWrite=$?
          if [ $overWrite = 0 ]; then
            Echo_Color g "Use same ssh-key~"
            break
          else
            ssh-agent -k
          fi
        fi
          eval `ssh-agent`
          ssh-add "${acc_info[4]}" # ssh-add private_key
          git config --global user.name "${acc_info[2]}"  # git global user.name
          git config --global user.email "${acc_info[3]}" # git global user.email
      fi
    done
  fi

  unset -f Echo_Color Ask_yn _acc
  unset -v GIT_ACC_ARG GIT_ACC user_name user_mail users_info cut_accs_line cut_username overWrite acc_info
}

function _git-acc() {
  local -a accnames
  # Get account names from .gitacc file
  if [ -f "$HOME/.gitacc" ]; then
    accnames=($(grep '\[.*\]' "$HOME/.gitacc" | cut -d '[' -f2 | cut -d ']' -f1))
  fi

  _arguments \
    "1: :(${accnames[*]})" \
    "-h[Show help]" \
    "--help[Show help]" \
    "-l[List accounts]" \
    "--list[List accounts]" \
    "-add[Add account]" \
    "--add_account[Add account]" \
    "-rm[Remove account]" \
    "--remove_account[Remove account]" \
    "-out[Logout]" \
    "--logout[Logout]"
}

compdef _git-acc git-acc