#!/usr/bin/env bash
 
set -e

reset="\033[0m"
bold="[1m"
yellow='[33m'
green='[32m'
blue='[34m'
purple='[35m'

get_repos() {
	curl --silent --user ":$GITHUB_TOKEN" https://api.github.com/user/repos
}

parse_repos() {
	declare raw_json=${*:-$(</dev/stdin)}
	printf "$raw_json" |
	jq --raw-output '.[] | "\(.name)^\(.full_name)^\(.fork)"'
}

mirror_repo() {
	repo_info="$1"
	name=$(echo "$repo_info" | cut -d'^' -f1)
	full_name=$(echo "$repo_info" | cut -d'^' -f2)
	fork=$(echo "$repo_info" | cut -d'^' -f3)

	if [ $fork == 'true' ]; then
		printf "\n${bold}${yellow}==>${reset}${reset} ${bold}Repo is a fork: ${yellow}${name}${reset}${bold}. Skipped${reset}${reset}\n"
		return
 	fi
	printf "\n${bold}${green}==>${reset}${reset} ${bold}Mirroring: ${green}${name}${reset}${reset}\n"
	clone_url="https://$GIT_USER:$GITHUB_TOKEN@github.com/${full_name}.git"
	git clone --quiet --bare "$clone_url"
	cd "${name}.git"
	if [ $GITLAB_TOKEN ]; then
		printf "==> Cloning to ${bold}Gitlab${reset}\n"
		git push --mirror "https://$GIT_USER:$GITLAB_TOKEN@gitlab.com/$GIT_USER/${name}.git"
	fi
	if [ $BITBUCKET_TOKEN ]; then
		printf "==> Cloning to ${bold}Bitbucket${reset}\n"		
		curl --silent --user "$GIT_USER:$BITBUCKET_TOKEN" --request POST "https://api.bitbucket.org/2.0/repositories/$GIT_USER/$name" --header "Content-type: application/json" --data '{"scmId":"git", "is_private":true}' > /dev/null
		git push --mirror "https://$GIT_USER:$BITBUCKET_TOKEN@bitbucket.org/$GIT_USER/${name}.git"
	fi
	if [ $GITEA_TOKEN ]; then
		printf "==> Cloning to ${bold}Gitea${reset}\n"
		curl --silent --request POST "https://gitea.com/api/v1/user/repos" --header "Content-type: application/json" --header "Authorization: token $GITEA_TOKEN" --data '{"auto_init":false, "name":"$name", "private":true}' > /dev/null
		git push --mirror "https://$GIT_USER:$GITEA_TOKEN@gitea.com/$GIT_USER/${name}.git"
	fi
	cd ..
}

printf "${bold}${blue}==> Starting to clone Github user ${purple}$GIT_USER${reset} ${bold}${blue}repos...${reset}${reset}\n"
cd "$(mktemp -d)"
get_repos | parse_repos |
while read repo_info; do
	mirror_repo "$repo_info"
done
printf "\n\n${bold}${green}✔ All repos successfully mirrored${reset}${reset}\n"
