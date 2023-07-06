import sys
import os
import re
from bs4 import BeautifulSoup

root_folder = sys.argv[1]

htmlfilepath = os.path.join(root_folder,"target","response.html")
do_notify = False

available_date = ""

with open(htmlfilepath) as htmlfile:
    soup = BeautifulSoup(htmlfile.read(), 'html.parser')
    h4elems = soup.find("div",{"id":"content"}).find_all("h4")
    for elem in h4elems:
        tokens = elem.text.strip().split(" ")
        date_tokens = tokens[1].split(".")
        #If date is in march, and greater than 24
        #print("date part is : "+ date_tokens[1])
        #print("Month part is : "+ date_tokens[0])
        if(int(date_tokens[1]) > 0 and int(date_tokens[0]) < 31):
            do_notify = True
            available_date = '.'.join(date_tokens)
            break;

    print("NONE" if not do_notify else str(available_date))

exit(0)
