#!/bin/sh

DROPBOX_HOME="$HOME/Dropbox"
XCAB_HOME="${DROPBOX_HOME}/`cat ${DROPBOX_HOME}/.com.PDAgent.XCAB.settings`"
SCM_WORKING_DIR="$HOME/src"
OVER_AIR_INSTALLS_DIR="$HOME/src/OverTheAirInstalls"

#TODO - dynamically get the profile
provprofile="/Users/carlb/Library/MobileDevice/Provisioning Profiles/42348AF7-5BCE-440E-AAF8-E00B7398198C.mobileprovision"

if [ ! -d "$OVER_AIR_INSTALLS_DIR" ] ; then
	mkdir -p "$OVER_AIR_INSTALLS_DIR"
fi

build_time_human="`date +%Y%m%d%H%M%S`"

now="`date '+%s'`"
days=1 # don't build things more than 7 days old
cutoff_window="`expr $days \* 24 \* 60 \* 60`" 
cutoff_time="`expr $now - $cutoff_window`"

cd $XCAB_HOME

for target in *; do
	if [ -d "$SCM_WORKING_DIR/$target" ] ; then
		cd "$SCM_WORKING_DIR/$target"
		if [ ! -d "$OVER_AIR_INSTALLS_DIR/$target" ] ; then
			mkdir -p "$OVER_AIR_INSTALLS_DIR/$target"
		fi
		
		already_built="`cat $OVER_AIR_INSTALLS_DIR/$target/*/sha.txt`"
		
		for candidate in `git branch -l | sed -e 's/^..//'` ; do
			sha="`git rev-parse $candidate`"
			commit_time="`git log -1 --pretty=format:"%ct" $sha`"
			if [ $commit_time -gt $cutoff_time ] ; then
				is_built="`echo $already_built | grep $sha`"
				if [ -z "$is_built" ] ; then
					git checkout -f $candidate
					git reset --hard $candidate
					git clean -d -f -x
					build_target=`xcodebuild -list | awk '$1=="Targets:",$1==""' | grep -v "Targets:" | grep -v "^$" | sed -e 's/^  *//' | head -1`
					xcodebuild build -target $build_target
					mkdir -p $OVER_AIR_INSTALLS_DIR/$target/$build_time_human
					
					xcrun -sdk iphoneos PackageApplication "./build/Release-iphoneos/${build_target}.app" -o "/tmp/${build_target}.ipa" --sign "iPhone Developer" --embed $provprofile
					betabuilder /tmp/${build_target}.ipa $OVER_AIR_INSTALLS_DIR/$target/$build_time_human http://www.pdagent.com/XCAB/${build_target}/$build_time_human
					echo "$sha" > "$OVER_AIR_INSTALLS_DIR/$target/$build_time_human/sha.txt"
				fi
			fi
		done
		
	fi
	cd $XCAB_HOME
done