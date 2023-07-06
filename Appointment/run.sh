#!/bin/bash

extract_time_period()
{
    searchtext=$1

    saveIFS=$IFS
    IFS='=&'
    params=($searchtext)
    IFS=$saveIFS

    declare -A array
    for ((i=0; i<${#params[@]}; i+=2))
    do
        array[${params[i]}]=${params[i+1]}
    done

    time_period=${array["openingPeriodId"]}
}

solve_captcha()
{
    captcha_page=$1
    captcha_selector=$2

    #Extract captcha base64 image and save to a file (will save to ../target/captcha.jpg)
    python3 lib/extract_captcha.py "$root_folder" "$captcha_page" "$captcha_selector"
    echo -e "Extract base64 encoded captcha image and saved at target/captcha.jpg" >> $log_file

    #Send Captcha Request for Solving and wait till there is a response
    cd target
    #register in deathbycaptcha to get credentials
    ../lib/deathbycaptcha -l mhaseeb -p Pakistan.123 -c $root_folder/target/captcha.jpg

    solution=$(cat answer.txt)
    echo -e "Captcha has been solved - RequestId : $(cat id.txt) - Answer : $solution" >> $log_file

    cd $root_folder
}

solve_captcha2()
{
    captcha_page=$1
    captcha_selector=$2

    #Extract captcha base64 image and save to a file (will save to ../target/captcha.jpg)
    python3 lib/extract_captcha2.py "$root_folder" "$captcha_page" "$captcha_selector"
    echo -e "Extract base64 encoded captcha image and saved at target/captcha.jpg" >> $log_file

    #Send Captcha Request for Solving and wait till there is a response
    cd target
    #register in deathbycaptcha to get credentials
    ../lib/deathbycaptcha -l mhaseeb -p Pakistan.123 -c $root_folder/target/captcha.jpg

    solution=$(cat answer.txt)
    echo -e "Captcha has been solved - RequestId : $(cat id.txt) - Answer : $solution" >> $log_file

    cd $root_folder
}

#Switch working directory to the root folder
source ./setenv
cd $root_folder

log_file="$root_folder/log/log.txt"

echo -e "\n\n" >> $log_file
echo Starting Process at $(date "+%Y-%m-%d %H:%M:%S") >> $log_file

#cleanup artifacts from last run
rm -rf target
mkdir target

#Fetch Captcha Page from german consulate
link_to_look_for_appointments="$consulate_base_url?$consulate_details"
curl -v -L -s -S -b target/cookies -c target/cookies -o target/captchapage.html "$link_to_look_for_appointments"
echo -e "Saved captchapage.html at target/captchapage.html alongwith cookies" >> $log_file

#Wait for the page to be saved
sleep 5
echo Time before $(date "+%Y-%m-%d %H:%M:%S") >> $log_file
solve_captcha "captchapage.html" "appointment_captcha_month"
echo Time After $(date "+%Y-%m-%d %H:%M:%S") >> $log_file

#Get HTML page with latest available dates
curl -X POST -v -L -s -S -F request_locale=en -F captchaText=$solution -F locationCode=$locationCode -F realmId=$realmId -F categoryId=$categoryId -F dateStr=05.08.2023 -b target/cookies -c target/cookies -o target/response.html "$consulate_base_url"

#Parse HTML and see if notification is required
available_date=$(python3 lib/parse_response.py $root_folder)

if [ "$available_date" != "NONE" ]; then
    # Using Automate app in android to create a flow which waits for a cloud message
    # and plays a sound to alert user whenever a message is sent. Sending that message now
    echo "Available date is $available_date"  >> $log_file
    echo "Need to notify : True" >> $log_file
    echo -e "Sending Cloud Messaging Request to notify android phone." >> $log_file

    #Notify telegram bot

    curl -s -X POST https://api.telegram.org/bot6063662911:AAFTj8Z_X84-iG4Kbswx24yBL-v1f0g36wo/sendMessage -d chat_id=1939262466 -d text=$available_date

    #****** Automatically book the appointment ********

    echo -e "Booking Appointment automatically..." >> $log_file

    #Get Appointment time selection page
    curl -v -L -s -S -b target/cookies -c target/cookies -o target/appointmentschedulingpage.html "$rescheduling_base_url?$consulate_details&dateStr=$available_date"

    resch_appt_url=$host/$(python3 lib/extract_resch_appt_url.py $root_folder "appointmentschedulingpage.html")
    echo "booking url is $resch_appt_url" >> $log_file

    #Fetch final booking page
    curl -v -L -s -S -b target/cookies -c target/cookies -o target/bookfinalappt.html "$resch_appt_url"

    #Extract booking time
    #booking_time=$(python3 lib/extract_booking_time.py $root_folder "bookfinalappt.html")

    #Extract openingPeriodId
    extract_time_period "$resch_appt_url"

    #Solve Captcha
    solve_captcha2 "bookfinalappt.html" "appointment_newAppointmentForm"

    sleep 5
    #echo -e "Booking appointment for $booking_time" >> $log_file

    if [ "$locationCode" == "sing" ]; then
        data="lastname=${lastname}&firstname=${firstname}&email=${email}&emailrepeat=${emailrepeat}&fields%5B0%5D.content=${phone_content}&fields%5B0%5D.definitionId=${phone_definitionId}&fields%5B0%5D.index=${phone_index}&fields%5B1%5D.content=${passport_content}&fields%5B1%5D.definitionId=${passport_definitionId}&fields%5B1%5D.index=${passport_index}&fields2content=${birthdate}&fields%5B2%5D.content=${birthdate_content}&fields%5B2%5D.definitionId=${birthdate_definitionId}&fields%5B2%5D.index=${birthdate_index}&fields%5B3%5D.content=${purpose_content}&fields%5B3%5D.definitionId=${purpose_definitionId}&fields%5B3%5D.index=${purpose_index}&captchaText=${solution}&locationCode=${locationCode}&realmId=${realmId}&categoryId=${categoryId}&openingPeriodId=${time_period}&date=$available_date&dateStr=$available_date&action%3Aappointment_addAppointment=Submit"
        curl -X POST -v -b target/cookies -c target/cookies -o target/bookingdone.html -d "$data" "$booking_base_url"
    elif [ "$locationCode" == "isla" ]; then # for islamabad visit visa #data is taking values defined in setenv
        data="lastname=${lastname}&firstname=${firstname}&email=${email}&emailrepeat=${emailrepeat}&fields%5B0%5D.content=${passport_content}&fields%5B0%5D.definitionId=${passport_definitionId}&fields%5B0%5D.index=${passport_index}&fields%5B1%5D.content=${citizenship_content}&fields%5B1%5D.definitionId=${citizenship_definitionId}&fields%5B1%5D.index=${citizenship_index}&captchaText=${solution}&locationCode=${locationCode}&realmId=${realmId}&categoryId=${categoryId}&openingPeriodId=${time_period}&date=$available_date&dateStr=$available_date&action%3Aappointment_addAppointment=Submit"
    else
        data="NONE"
        echo "Location not defined , $locationCode, $data" >> $log_file 
    fi
    if [ "$data" == "NONE" ]; then
        echo "Data is empty" >> $log_file
    else
        echo "Data : $data " >> $log_file
    fi
    #Book Appointment
      #lastname=test&firstname=testov&email=www%40eee.com&emailrepeat=www%40eee.com&fields%5B0%5D.content=a2345676&fields%5B0%5D.definitionId=4590&fields%5B0%5D.index=0&fields%5B1%5D.content=380997776655&fields%5B1%5D.definitionId=4591&fields%5B1%5D.index=1&captchaText=ca7ewy&locationCode=kiew&realmId=561&categoryId=1497&openingPeriodId=34537&date=30.12.2019&dateStr=30.12.2019&action%3Aappointment_addAppointment=Submit
    #curl -X POST -v -L -s -S -F request_locale=en -F captchaText=$solution -F locationCode=sing -F realmId=561 -F categoryId=1785 -F openingPeriodId=$time_period -F date=$available_date -F dateStr=$available_date -F rebooking=true -F token=$rescheduling_token -F action:appointment_rebookAppointment=Submit -b target/cookies -c target/cookies -o target/bookingdone.html "$booking_base_url"
else
    echo Need to notify : True >> $log_file
fi


echo Process Finished at $(date "+%Y-%m-%d %H:%M:%S") >> $log_file
