#!/usr/bin/env bash

lightning_cli=lightning-cli

if ! which "$lightning_cli" > /dev/null 2>&1; then
    echo "$lightning_cli is not executable"
    exit 1
fi

all_channels="$($lightning_cli listfunds | jq -r ".channels[].short_channel_id")"
all_forwards="$($lightning_cli listforwards | jq ".forwards[] | [select(.status == \"settled\")]")"

echo "\"short_channel_id\",\"count_in\",\"msatoshi_fees_collected_in\",\"count_out\",\"msatoshi_fees_collected_out\""

count_ins="$(echo "$all_forwards" | jq "group_by(.in_channel) | map({ in_channel: .[0].in_channel, count: length }) | .[]")"
count_outs="$(echo "$all_forwards" | jq "group_by(.out_channel) | map({ out_channel: .[0].out_channel, count: length }) | .[]")"

function count_forwards()
{
	field_name=$1
	channel_id=$2
	count="$(cat | jq "select(.$field_name == \"$channel_id\") | .count")"
	if [ "$count" == "" ]; then
		count=0
	fi
	echo $count
}

function sum_forwards()
{
	field_name=$1
	channel_id=$2
	sum="$(cat | jq ".[] | select(.$field_name == \"$channel_id\") | .fee" | paste -sd+ - | bc)"
	if [ "$sum" == "" ]; then
		sum=0
	fi
	echo $sum
}

for channel in $all_channels; do
	echo -n "\"$channel\","
	echo -n "$(echo "$count_ins" | count_forwards in_channel "$channel"),"
	echo -n "$(echo "$all_forwards" | sum_forwards in_channel "$channel"),"
	echo -n "$(echo "$count_outs" | count_forwards out_channel "$channel"),"
	echo -n "$(echo "$all_forwards" | sum_forwards out_channel "$channel")"
	echo
done
