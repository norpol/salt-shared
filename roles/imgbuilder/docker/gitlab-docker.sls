[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
[remote "origin"]
	fetch = +refs/heads/*:refs/remotes/origin/*
	url = https://github.com/crashsystems/gitlab-docker
[branch "master"]
	remote = origin
	merge = refs/heads/master
