# Display Attach Manager for tmux (remote) sessions with hooks
_dam_sessions ()
{
    COMPREPLY=();
    cur="${COMP_WORDS[COMP_CWORD]}";
    declare -A hostable;

    while IFS= read -r ahost; do                #get existing tmux session names
        ahost=${ahost%%":"*};                   #take first word split on colon
        hostable["${ahost}"]="";
    done < <(tmux ls 2>/dev/null); 
    while IFS= read -r ahost; do                #use known_hosts for possible completions
        [ "${ahost:0:1}" = "@" ] && continue;   #ignore @cert-authority and @revoked
        ahost=${ahost%%' '*};                   #take first word split on space
        ahost=${ahost%%','*};                   #take first word split on comma
        hostable["${ahost}/"]="";
    done < ~/.ssh/known_hosts;
    while IFS= read -r ahost; do                #ssh config for possible completions
        case "$ahost" in
            *'*'*) ahost="";;                   #ignore wild card hosts
            Host*) ahost="${ahost##*' '}";;     #last word split on space
            *) ahost="";;                       #ignore all else
        esac;
        hostable["${ahost}/"]="";               # lone / is legitimate argument
    done < ~/.ssh/config;

    case "${cur}" in
        */*)        #route connection via ssh
            damhost=${cur%%'/'*};
            thehost=${damhost:-$HOSTNAME};
            if ( command ssh -q -o BatchMode=yes $thehost true); then
                declare -A dam_hosted_sessions;
                while IFS= read -r asession; do
                    asession=${asession%%":"*};
                    dam_hosted_sessions["$damhost/${asession}"]=;
                done < <( command ssh -qt -o BatchMode=yes ${thehost} "tmux ls 2> /dev/null"); 
                dam_sessions="${!dam_hosted_sessions[@]}";
            else
                dam_sessions=${cur};        #can't ssh to host, assume user knows what they are doing
            fi
            ;;
        *)          #route connection locally
            dam_sessions="${!hostable[@]}";
            ;;
    esac

    COMPREPLY=( $(compgen -W "${dam_sessions}" -- $cur));
    return 0;
}
complete -o nospace -F _dam_sessions dam

# Hook system - executable scripts in ~/.config/dam/{help,pre,setup,post}/{host/session,host,default}
DAM_HOOKS="${DAM_HOOKS:-$HOME/.config/dam}"

_run_hook() {
    local when="$1" host="$2" session="$3"
    for hook in "$DAM_HOOKS/$when/$host/$session" "$DAM_HOOKS/$when/$host" "$DAM_HOOKS/$when/default"; do
        [[ -x "$hook" ]] && { "$hook" "$host" "$session" &>/dev/null || true; break; }
    done
}

_session_exists() {
    local host="$1" session="$2"
    if [[ "$host" == "$HOSTNAME" ]]; then
        tmux has-session -t "$session" &>/dev/null
    else
        ssh -q -o BatchMode=yes "$host" "tmux has-session -t '$session'" &>/dev/null
    fi
}

dam () {
    # Handle help as a hook
    case "$1" in
        -h|--help) _run_hook "help" "dam" ""; return 0 ;;
    esac

    local DamHost=${1%%"/"*} DamSess=${1##*"/"}
    DamHost=${DamHost:-$HOSTNAME}
    DamSess=${DamSess:-"mine"}
    
    _run_hook "pre" "$DamHost" "$DamSess"
    
    # Check if session exists for setup hook decision
    local session_exists=false
    [[ "$DamHost" == "$HOSTNAME" ]] && tmux has-session -t "$DamSess" &>/dev/null && session_exists=true
    [[ "$DamHost" != "$HOSTNAME" ]] && ssh -q -o BatchMode=yes "$DamHost" "tmux has-session -t '$DamSess'" &>/dev/null && session_exists=true
    
    case "$1" in
        */*)
            [ "$TMUX" ] && tmux rename-window "$1"
            ssh $DamHost -O check &>/dev/null && (timeout 3 ssh $DamHost exit || ssh $DamHost -O exit)
            if [[ "$session_exists" == "true" ]]; then
                ssh -Aq $DamHost -t "tmux attach -dt $DamSess"
            else
                ssh -Aq $DamHost -t "tmux new -s $DamSess -d"
                _run_hook "setup" "$DamHost" "$DamSess"
                ssh -Aq $DamHost -t "tmux attach -t $DamSess"
            fi
            [ "$TMUX" ] && tmux set-window-option automatic-rename "on" &>/dev/null
            ;;
        *)
            if [[ "$session_exists" == "true" ]]; then
                tmux attach -dt $DamSess
            else
                tmux new -s $DamSess -d
                _run_hook "setup" "$DamHost" "$DamSess"
                tmux attach -t $DamSess
            fi
    esac
    
    _run_hook "post" "$DamHost" "$DamSess"
}
