# Adapted from code found at <https://gist.github.com/1712320>.

setopt prompt_subst
autoload -U colors && colors # Enable colors in prompt

export CLICOLOR=1;
alias ls='ls -Fh'

# Modify the colors and symbols in these variables as desired.
GIT_PROMPT_PREFIX="["
GIT_PROMPT_SUFFIX="]"
GIT_PROMPT_CLEAN=""
GIT_PROMPT_AHEAD="↑NUM"
GIT_PROMPT_BEHIND="↓NUM"
GIT_PROMPT_MERGING="%{$fg[magenta]%}⇇ %{$reset_color%}"
GIT_PROMPT_UNTRACKED="%{$fg[red]%}?%{$reset_color%}"
GIT_PROMPT_MODIFIED="%{$fg[red]%}—%{$reset_color%}"
GIT_PROMPT_STAGED="%{$fg[red]%}+%{$reset_color%}"
GIT_PROMPT_MODIFIED_AND_STAGED="%{$fg[red]%}±%{$reset_color%}"

# Get the contents of the git branch/sha/tag names. This will be displayed in a format of:
# (branch-only) master
# (branch,tagged) master|v1.0
# (branch,multi-tagged) master|v1.0,beta
# (off-branch) 4b22c31
# (off-branch,tagged) 4b22c31|v1.0
parse_git_branch() {
  # First, just make sure that we're actually in a git repo by making sure
  # that we have a commit hash
  ref=$(git rev-parse --short HEAD 2> /dev/null) || return

  local branchOrSHA=$(current_branch)
  local display="$branchOrSHA"
  local tags=$(git tag --points-at HEAD | tr "\n" " " | sed 's/ *$//' | tr " " "," 2> /dev/null)
  if [[ -n $tags ]]; then
    display="$display|$tags"
  fi
  echo $display
}

# Show different symbols as appropriate for various Git repository states
parse_git_state() {

  # Compose this value via multiple conditional appends.
  local GIT_STATE=""
  local REMOTES=""
  local BRANCH_COLOR="%{$fg[white]%}"
  local MODIFIED
  local STAGED
  local MERGING

  local NUM_AHEAD="$(git log --oneline @{u}.. 2> /dev/null | wc -l | tr -d ' ')"
  if [ "$NUM_AHEAD" -gt 0 ]; then
    REMOTES=$REMOTES"%{$fg[cyan]%}${GIT_PROMPT_AHEAD//NUM/$NUM_AHEAD}"
  fi

  local NUM_BEHIND="$(git log --oneline ..@{u} 2> /dev/null | wc -l | tr -d ' ')"
  if [ "$NUM_BEHIND" -gt 0 ]; then
    REMOTES=$REMOTES"%{$fg[magenta]%}${GIT_PROMPT_BEHIND//NUM/$NUM_BEHIND}"
  fi

  # Detect if there are any merge conflicts
  local STATUS="$(git status --porcelain 2>/dev/null)"
  if [[ -n $(egrep '^.[(UU)]' <<<"$STATUS") ]]; then
    # GIT_STATE=$GIT_STATE"⚡  "
    GIT_STATE=$GIT_STATE"%{$fg[yellow]%}▲ %{$reset_color%}"
  fi

  # Detect if the repo is in a merging state
  local GIT_DIR="$(git rev-parse --git-dir 2> /dev/null)"
  if [ -n $GIT_DIR ] && test -r $GIT_DIR/MERGE_HEAD; then
    GIT_STATE=$GIT_STATE$GIT_PROMPT_MERGING
    MERGING=1
  fi

  # Detect if there are any untracked files in the repo 
  if [[ -n $(git ls-files --other --exclude-standard 2> /dev/null) ]]; then
    GIT_STATE=$GIT_STATE$GIT_PROMPT_UNTRACKED
    BRANCH_COLOR="%{$fg[red]%}"
  fi

  # Detect if there are any files that are modified but not staged
  if ! git diff --quiet 2> /dev/null; then
    MODIFIED=1
  fi

  # Detect if there are any files in the staging area
  if ! git diff --cached --quiet 2> /dev/null; then
    STAGED=1
  fi

  if [ $MODIFIED ] && [ ! $STAGED ]; then
    GIT_STATE=$GIT_STATE$GIT_PROMPT_MODIFIED
    BRANCH_COLOR="%{$fg[red]%}"
  fi

  if [ ! $MODIFIED ] && [ $STAGED ]; then
    GIT_STATE=$GIT_STATE$GIT_PROMPT_STAGED
    BRANCH_COLOR="%{$fg[red]%}"
  fi

  if [ $MODIFIED ] && [ $STAGED ]; then
    GIT_STATE=$GIT_STATE$GIT_PROMPT_MODIFIED_AND_STAGED
    BRANCH_COLOR="%{$fg[red]%}"
  fi

  if [ $MERGING ]; then
    BRANCH_COLOR="%{$fg[magenta]%}"
  fi

  if [[ -z $GIT_STATE ]]; then
    GIT_STATE=$GIT_STATE$GIT_PROMPT_CLEAN
    BRANCH_COLOR="%{$fg[green]%}"
  fi


  local GIT_BRANCH="${git_where#(refs/heads/|tags/)}"
  local OUTPUT="" 
  OUTPUT=$OUTPUT"$GIT_STATE$BRANCH_COLOR$GIT_PROMPT_PREFIX"

  if [[ -n $REMOTES ]]; then
    OUTPUT=$OUTPUT"$REMOTES$BRANCH_COLOR|"
  fi
  OUTPUT=$OUTPUT"$GIT_BRANCH$GIT_PROMPT_SUFFIX%{$reset_color%}"
  echo $OUTPUT
}

# If inside a Git repository, print its branch and state
git_prompt_string() {
  local git_where="$(parse_git_branch)"
  if [[ -n $git_where ]]; then
    # If we are inside a git repo that has a commit sha, print the standard
    # git prompt info.
    echo "$(parse_git_state)"
  else
    if git rev-parse --git-dir > /dev/null 2>&1; then
      # This is a valid git repository (but the current working
      # directory may not be the top level.
      # Check the output of the git rev-parse command if you care)
      echo "<new git repo>"
    fi
  fi
}


# Set the right-hand prompt
RPS1='$(git_prompt_string)'

# --PROMPT AS --
PROMPT=$'\
%{$fg[cyan]%}%n%{$fg[white]%}|%{$fg_no_bold[cyan]%}%m: %{$fg[yellow]%}$(get_pwd)\
%{$reset_color%}→ '

#
# get_pwd()
# Function to replace the /Users/jtm with ~
#
function get_pwd() {
 echo "${PWD/$HOME/~}"
}
