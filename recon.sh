echo "${red}
 .  o ..
 o . o o.o
      ...oo
        __[]__
     __|_o_o_o\__
     \\""""""""""//
      \\. ..  . //
 ^^^^^^^^^^^^^^^^^^^^
${reset}                                                      "

echo "${blue}Did you install everything?${reset}"
while true; do
    read -p "Press [Y] for: Yes of course I did or [N] for: Nope, I'm a noob] " yn
    case $yn in
        [Yy]* ) echo "you shall pass"; break;;
        [Nn]* ) echo "YOU SHALL NOT PASS, gtfo. TL;DR go and install all the tools, (install script coming soon)"; exit;;
        * ) echo "Doh! Please answer [Y] or [N].";;
    esac
done

echo "creating dirs and files"
mkdir ./$1
mkdir ./$1/ffuf
touch ./$1/domains
touch ./$1/mass-domains.txt
touch ./$1/domains-resolved.txt
touch ./$1/takeover
touch ./$1/responsive-domains
touch ./$1/ports.txt
touch ./$1/interestingsubs
touch ./$1/all_the_urls
touch ./$1/javascript_files
touch ./$1/redirects
touch ./$1/idor
touch ./$1/rce
touch ./$1/lfi
touch ./$1/xss
touch ./$1/ssrf

# Hunting for subdomains
echo "Starting Discovery. This WILL take a while..."

echo "subfinder..."
subfinder -d $1 -o ./$1/domains > /dev/null

echo "subfinder finished -> assetfinder" 
assetfinder -subs-only $1 | tee -a ./$1/domains > /dev/null

echo "assetfinder finished -> crt.sh"
curl -s "https://crt.sh/\?q\=%25.$1\&output\=json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u | tee -a ./$1/domains  > /dev/null

echo "crt.sh finished -> DNS Resolve with MassDNS"
~/tools/massdns/scripts/subbrute.py ~/tools/SecLists/Discovery/DNS/clean-jhaddix-dns.txt $1 | ~/tools/massdns/bin/massdns -r ~/tools/massdns/lists/resolvers.txt -t A -q -o S -w ./$1/mass-domains.txt
cat ./$1/mass-domains.txt >> ./$1/domains

echo "DNS Resolve with MassDNS finished -> altdns"
altdns -i ./$1/domains -o ./$1/altdns_output -w ~/tools/wordlists/altdns-words.txt -r -s ./$1/domains-resolved.txt

echo "Finished discovery. Now we move onto the pokey bits"

echo "can we find some takeovers?"
subjack -w ./$1/domains -t 100 -timeout 30 -ssl -c ~/golang/src/github.com/haccer/subjack/fingerprints.json -v | tee -a ./$1/takeover

echo "probe them"
cat ./$1/domains | httprobe | tee -a ./$1/responsive-domains

# Take resolved domains and start enum
echo "nmap ofc"
nmap  -T4  -iL ./$1/responsive-domains -Pn --script=http-title -p80,4443,4080,443 --open | tee -a ./$1/ports.txt

echo "Interesting subs?"
gf interestingsubs ./$1/responsive-domains > ./$1/interestingsubs

echo "endpoint discovery, hold tight we might have something ;)"
while read -r url ; do ffuf -u https://$url/FUZZ -w ~/tools/SecLists/Discovery/Web-Content/directory-list-2.3-big.txt -se -sf -mc all -c -recursion -recursion-depth 2 -fc 300,301,302,303,500,400,404 | tee -a ./$1/ffuf/$url.txt; done < ./$1/responsive-domains
cat ./$1/responsive-domains | gau | tee -a ./$1/all_the_urls
cat ./$1/responsive-domains | hakrawler --depth 3 --plain | tee -a ./$1/all_the_urls

echo "gf patternining"
gf redirect ./$1/all_the_urls | anti-burl > ./$1/redirects
gf idor ./$1/all_the_urls | anti-burl > ./$1/idor
gf rce ./$1/all_the_urls | anti-burl > ./$1/rce
gf lfi ./$1/all_the_urls | anti-burl > ./$1/lfi
gf xss ./$1/all_the_urls | anti-burl > ./$1/xss
gf ssrf ./$1/all_the_urls | anti-burl > ./$1/ssrf

echo "get me the js files"
grep "\.js$" ./$1/all_the_urls | anti-burl | grep -Eo "(http|https)://[a-zA-Z0-9./?=_-]*" | sort -u | tee -a ./$1/javascript_files

echo "Lets do some JS enum. Might be something hidding"
mkdir ./$1/js_files;cd ./$1/js_files; while read LINE; do wget $LINE; done < $1 ../$1/javascript_files; cat * >> GF; gf sec GF > gf_sec; rm GF; > sec; cd ..