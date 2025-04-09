#!/usr/bin/env bash

# Function to detect the current shell
detect_shell() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ]; then
        echo "bash"
    else
        echo "unknown"
    fi
}

# Color output function compatible with both shells
Echo_Color() {
    case $1 in
        r* | R* ) COLOR='\033[0;31m' ;;
        g* | G* ) COLOR='\033[0;32m' ;;
        y* | Y* ) COLOR='\033[0;33m' ;;
        b* | B* ) COLOR='\033[0;34m' ;;
        *)
        echo "Wrong COLOR keyword!" >&2
        return 1
        ;;
    esac
    echo -e "${COLOR}$2\033[0m"
}

# Main installation function
install_gitacc() {
    local current_shell=$(detect_shell)
    local profile
    local logout_profile

    case $current_shell in
        zsh)
        profile=~/.zshrc
        logout_profile=~/.zlogout
        ;;
        bash)
        profile=~/.bashrc
        logout_profile=~/.bash_logout
        ;;
        *)
        Echo_Color r "Unknown shell, need to manually add config to your shell profile!"
        profile='unknown'
        logout_profile='unknown'
        ;;
    esac

    local gitacc_config='# git account switch
    source "$HOME/.git-acc"'

    # Copy the main script
    if [ -f "./git-acc.sh" ]; then
        cp "./git-acc.sh" ~/.git-acc || {
        Echo_Color r "Failed to copy git-acc script!"
        return 1
        }
        chmod +x ~/.git-acc
    else
        Echo_Color r "Error: git-acc.sh not found in current directory!"
        return 1
    fi

    if [ "$profile" = "unknown" ]; then
        Echo_Color y "\nPaste the following into your shell profile:"
        echo -e "$gitacc_config\n"
        
        if [ -f "./logout.script" ]; then
        Echo_Color y "\nPaste the following into your logout profile:"
        cat "./logout.script"
        echo
        fi
    else
        # Check if config already exists
        if grep -qF "source \"\$HOME/.git-acc\"" "$profile"; then
        Echo_Color g "git-acc config already exists in $profile"
        Echo_Color g "Only updating the git-acc script"
        else
        # Add to profile
        printf "\n%s\n" "$gitacc_config" >> "$profile" || {
            Echo_Color r "Failed to update $profile!"
            return 1
        }
        Echo_Color g "Added git-acc config to $profile"

        # Add logout script if exists
        if [ -f "./logout.script" ]; then
            if [ -f "$logout_profile" ] && grep -qF "$(cat ./logout.script)" "$logout_profile"; then
            Echo_Color g "Logout script already exists in $logout_profile"
            else
            cat "./logout.script" >> "$logout_profile" || {
                Echo_Color r "Failed to update $logout_profile!"
                return 1
            }
            Echo_Color g "Added logout script to $logout_profile"
            fi
        fi
        fi
    fi

    # Create empty .gitacc file if it doesn't exist
    if ! [ -f ~/.gitacc ]; then
        touch ~/.gitacc || {
        Echo_Color r "Failed to create ~/.gitacc file!"
        return 1
        }
        Echo_Color g "Created empty ~/.gitacc file"
    fi

    # Source the profile if not unknown shell
    if [ "$profile" != "unknown" ]; then
        if [ "$current_shell" = "zsh" ]; then
        # For zsh, we need to make sure compinit is loaded
        if ! grep -q "compinit" "$profile"; then
            echo -e "\n# Enable zsh completions\nautoload -Uz compinit\ncompinit" >> "$profile"
        fi
        fi
        
        # Source the profile
        Echo_Color g "\nReloading shell profile..."
        if [ -n "$BASH_VERSION" ]; then
        source "$profile"
        else
        # In zsh, we need to emulate bash for sourcing
        emulate bash -c "source \"$profile\""
        fi
    fi

    Echo_Color g "\nInstallation complete! You can now use git-acc."
    Echo_Color y "To get started, try:"
    Echo_Color y "  git-acc --help"
}

# Run the installation
install_gitacc