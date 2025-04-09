#!/usr/bin/env bash

# Detect shell type
if [ -n "$ZSH_VERSION" ]; then
  SHELL_TYPE="zsh"
elif [ -n "$BASH_VERSION" ]; then
  SHELL_TYPE="bash"
else
  echo "Error: This script only supports bash and zsh" >&2
  return 1 2>/dev/null || exit 1
fi

function git-acc(){
  # Color output function compatible with both shells
  function Echo_Color(){
    case $1 in
      r* | R* ) COLOR='\033[0;31m' ;;
      g* | G* ) COLOR='\033[0;32m' ;;
      y* | Y* ) COLOR='\033[0;33m' ;;
      b* | B* ) COLOR='\033[0;34m' ;;
      *) echo "Wrong COLOR keyword!" >&2; return 1 ;;
    esac
    echo -e "${COLOR}$2\033[0m"
  }

  # Yes/No prompt compatible with both shells
  function Ask_yn(){
    printf "\033[0;33m$1 [y/n] \033[0m"
    read -r respond
    case "$respond" in
      [yY]) return 0 ;;
      [nN]) return 1 ;;
      *) 
        Echo_Color r 'wrong command!!'
        Ask_yn "$1"
        return $?
      ;;
    esac
  }

  # Account listing function
  function list_accounts() {
    if [ -f "$gitacc_locate" ]; then
      Echo_Color g "List of added Git accounts:"
      awk '
        /\[.*\]/ { 
          if (acc_name != "") { print "" }
          acc_name = substr($0, 2, length($0) - 2); 
          printf "Account: %s\n", acc_name; 
        } 
        /name =/ { printf "  Name: %s\n", $3; }
        /email =/ { printf "  Email: %s\n", $3; }
        /private_key =/ { printf "  Private Key: %s\n", $3; }
        /public_key =/ { printf "  Public Key: %s\n", $3; }
        END { if (acc_name != "") print "" }
      ' "$gitacc_locate"
    else
      Echo_Color r "No Git accounts have been added yet."
    fi
  }

  # Help function
  function show_script_help(){
    cat <<EOF
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
      -t, --type          ssh-key types, follow 'ssh-keygen' rule, 
                          types: dsa | ecdsa | ecdsa-sk | ed25519 | ed25519-sk | rsa(default)
  -rm, --remove_account   remove git_account info. & ssh-key from this device
  -out, --logout          logout your current ssh-acc.

EXAMPLES
  \$ git-acc tw-yshuang
  \$ git-acc --list
EOF
  }

  # Internal account functions
  function _acc(){
    local users_info=$(grep -n '\[.*\]' "$gitacc_locate" 2>/dev/null)
    if [ "$SHELL_TYPE" = "zsh" ]; then
      accs_line=($(echo "$users_info" | cut -f1 -d ':'))
      accnames=($(echo "$users_info" | cut -d '[' -f2 | cut -d ']' -f1))
    else
      IFS=$'\n' read -d '' -ra accs_line <<< "$(echo "$users_info" | cut -f1 -d ':')"
      IFS=$'\n' read -d '' -ra accnames <<< "$(echo "$users_info" | cut -d '[' -f2 | cut -d ']' -f1)"
    fi
  }

  # Main variables
  local ssh_key_locate="$HOME/.ssh/id_"
  local gitacc_locate="$HOME/.gitacc"
  local ssh_keygen_type="rsa"
  local GIT_ACC_ARG=()
  local GIT_ACC=()
  local user_name
  local user_mail
  local key_type
  local accs_line=()
  local accnames=()
  local overWrite=0
  local acc_info=()

  # List accounts if no arguments are given
  if [ "$#" -eq 0 ]; then
    list_accounts
    return 0
  fi

  # Parse arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        show_script_help
        return 0
        ;;
      -l|--list)
        list_accounts
        return 0
        ;;
      -add|--add_account)
        GIT_ACC_ARG+=('add')
        shift
        ;;
      -t|--type)
        ssh_keygen_type="$2"
        shift 2
        ;;
      -rm|--remove_account)
        GIT_ACC_ARG+=('rm')
        shift
        ;;
      -out|--logout)
        ssh-agent -k >/dev/null 2>&1
        unset SSH_AUTH_SOCK SSH_AGENT_PID
        git config --global --unset user.name
        git config --global --unset user.email
        shift
        ;;
      *)
        GIT_ACC+=("$1")
        shift
        ;;
    esac
  done

  # Handle add/remove account operations
  if [ "${#GIT_ACC_ARG[@]}" -gt 0 ]; then
    case "${GIT_ACC_ARG[0]}" in
      add)
        printf "Enter your git user name: "; read -r user_name
        printf "Enter your git user mail: "; read -r user_mail

        _acc
        for acc_name in "${accnames[@]}"; do
          if [ "$acc_name" = "$user_name" ]; then
            Echo_Color r "Warning: Already have same account name."
            if ! Ask_yn "Do you want to overwrite?"; then
              Echo_Color y "Please use another account name."
              return 1
            fi
            overWrite=1
            break
          fi
        done

        ssh_key_locate="${ssh_key_locate}${ssh_keygen_type}_${user_name}"
        ssh-keygen -t "$ssh_keygen_type" -C "$user_mail" -f "$ssh_key_locate"
        
        if [ "$overWrite" -eq 0 ]; then
          cat <<EOF >> "$gitacc_locate"
[$user_name]
	name = $user_name
	email = $user_mail
	private_key = $ssh_key_locate
	public_key = ${ssh_key_locate}.pub
EOF
        fi

        Echo_Color g "Your SSH publish key is:"
        cat "${ssh_key_locate}.pub"
        Echo_Color g "Paste it to your SSH keys in github or server."
        ;;
      rm)
        printf "Enter the git user name you want to remove: "; read -r user_name
        
        _acc
        local found=0
        for i in "${!accnames[@]}"; do
          if [ "${accnames[i]}" = "$user_name" ]; then
            found=1
            local start_line="${accs_line[i]}"
            local end_line
            
            if [ "$i" -eq $((${#accs_line[@]}-1)) ]; then
              end_line='$'
            else
              end_line=$((${accs_line[i+1]}-1))
            fi

            acc_info=($(sed -n "${start_line},${end_line}p" "$gitacc_locate" | awk -F ' = ' '/ = / {print $2}'))
            
            # Use sed compatible method to delete lines
            sed -i.bak "${start_line},${end_line}d" "$gitacc_locate" && rm -f "$gitacc_locate.bak"
            
            rm -f "${acc_info[2]}" "${acc_info[3]}" 2>/dev/null
            Echo_Color g "Account $user_name removed successfully."
            break
          fi
        done
        
        if [ "$found" -eq 0 ]; then
          Echo_Color r "Account not found: $user_name"
          return 1
        fi
        ;;
    esac
    return 0
  fi

  # Handle account switching
  if [ "${#GIT_ACC[@]}" -eq 1 ]; then
    _acc
    for i in "${!accnames[@]}"; do
      if [ "${accnames[i]}" = "${GIT_ACC[0]}" ]; then
        local start_line="${accs_line[i]}"
        local end_line
        
        if [ "$i" -eq $((${#accs_line[@]}-1)) ]; then
          end_line='$'
        else
          end_line=$((${accs_line[i+1]}-1))
        fi

        acc_info=($(sed -n "${start_line},${end_line}p" "$gitacc_locate" | awk -F ' = ' '/ = / {print $2}'))
        
        if [ -n "$SSH_AGENT_PID" ]; then
          if Ask_yn "You already have active git-agent on this shell, you want to overwrite it?"; then
            ssh-agent -k >/dev/null 2>&1
            unset SSH_AUTH_SOCK SSH_AGENT_PID
          else
            Echo_Color g "Using existing ssh-agent"
            break
          fi
        fi
        
        eval "$(ssh-agent -s)" >/dev/null
        ssh-add "${acc_info[2]}" 2>/dev/null
        git config --global user.name "${acc_info[0]}"
        git config --global user.email "${acc_info[1]}"
        Echo_Color g "Switched to account: ${GIT_ACC[0]}"
        return 0
      fi
    done
    Echo_Color r "Account not found: ${GIT_ACC[0]}"
    return 1
  elif [ "${#GIT_ACC[@]}" -gt 1 ]; then
    Echo_Color r 'Error: Only one account can be specified at a time'
    return 1
  fi
}

# Shell-specific completion setup
if [ "$SHELL_TYPE" = "zsh" ]; then
  # ZSH completion
  function _git-acc() {
    local -a accnames
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
elif [ "$SHELL_TYPE" = "bash" ]; then
  # Bash completion
  function _git-acc_completion() {
    local cur prev words cword
    _init_completion || return
    
    if [ "$cword" -eq 1 ]; then
      if [ -f "$HOME/.gitacc" ]; then
        COMPREPLY=($(compgen -W "$(grep '\[.*\]' "$HOME/.gitacc" | cut -d '[' -f2 | cut -d ']' -f1 | tr '\n' ' ') -h --help -l --list -add --add_account -rm --remove_account -out --logout" -- "$cur"))
      else
        COMPREPLY=($(compgen -W "-h --help -l --list -add --add_account -rm --remove_account -out --logout" -- "$cur"))
      fi
    elif [ "$cword" -eq 2 ] && [[ "${words[1]}" =~ ^(-add|--add_account|-rm|--remove_account)$ ]]; then
      if [ -f "$HOME/.gitacc" ]; then
        COMPREPLY=($(compgen -W "$(grep '\[.*\]' "$HOME/.gitacc" | cut -d '[' -f2 | cut -d ']' -f1 | tr '\n' ' ')" -- "$cur"))
      fi
    fi
  }
  complete -F _git-acc_completion git-acc
fi