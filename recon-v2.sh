# Hunting for subdomains
echo "Starting Discovery. This WILL take a while..."
echo "subfinder..."
subfinder -d $1 | tee -a domains > /dev/null
echo "subfinder finished -> assetfinder" 
assetfinder -subs-only $1 | tee -a domains > /dev/null
echo "assetfinder finished -> crt.sh"
curl -s "https://crt.sh/\?q\=%25.$1\&output\=json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u | tee -a domains  > /dev/null
echo "crt.sh finished -> DNS Resolve with MassDNS"
~/tools/massdns/scripts/subbrute.py ~/tools/SecLists/Discovery/DNS/clean-jhaddix-dns.txt $1 | ~/tools/massdns/bin/massdns -r ~/tools/massdns/lists/resolvers.txt -t A -q -o S -w mass-domains.txt
cat mass-domains.txt >> ./domains
echo "DNS Resolve with MassDNS finished -> altdns"
altdns -i domains -o data_output -w ~/tools/wordlists/altdns-words.txt -r -s domains-resolved.txt
echo "Finished Discovery"

# Get lucky: after resolving recon'd list of subs, filter subs that don't resolve into a list. Take all the IPs of the subs that did resolve, and:
cat ips.txt | httprobe | while read targ; do ffuf -u $targ -w non_resolv_subs.txt -H "Host: FUZZ" ; done

#sorting/uniq
#cat subb.txt >> domains
sort -u domains > dom2;rm domains;mv dom2 domains

#account takeover scanning
subjack -w domains -t 100 -timeout 30 -ssl -c /home/victor/go/src/github.com/haccer/subjack/fingerprints.json -v | tee -a takeover

#httprobing 
cat domains | httprobe | tee -a responsive
gf interestingsubs responsive > interestingsubs

#endpoint discovery
cat responsive | gau | tee -a all_urls
cat responsive | hakrawler --depth 3 --plain | tee -a all_urls

#extracting all responsive js files
grep "\.js$" all_urls | anti-burl | grep -Eo "(http|https)://[a-zA-Z0-9./?=_-]*" | sort -u | tee -a javascript_files

#analyzing js files for secrets
mkdir js;cd js;/home/victor/Desktop/bugHunting/tools/Bug-Bounty-Scripts/wgetlist ../javascript_files; cat * >> GF; gf sec GF > gf_sec; rm GF; > sec; cd ..

#grabing endpoints that include juicy parameters
gf redirect all_urls | anti-burl > redirects
gf idor all_urls | anti-burl > idor
gf rce all_urls | anti-burl > rce
gf lfi all_urls | anti-burl > lfi
gf xss all_urls | anti-burl > xss
gf xss all_urls | anti-burl > xss
gf ssrf all_urls | anti-burl > ssrf