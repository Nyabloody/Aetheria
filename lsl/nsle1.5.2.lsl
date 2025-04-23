#define COMPANION
#include "system.lsl"

// channels
integer channel_lights; // Lightbus channel
integer channel_private; // Unit private channel
integer channel_acsi; // ACS private channel
integer channel_rlvhook; // Used for chat capture
integer channel_acs = 360; // ACS public channel
integer channel_identify = -9999888; // ATOS channel for this controller to answer to remote devices 
integer channel_ping = -9999777; // Ping channel for this controller to answer to remote devices 
integer channel_public = -9999999; // NS public channel
integer channel_pong = -99999904; // Pong channel for remote devices to answer to this controller
integer channel_rlvrc = -1812221819; // RLV Relay
// messages
string light_msg;
string pub_msg;
string prv_msg;
string pong_msg;
string acs_msg;
string acsi_msg;
string color_msg;
// stuff for stargatetp
vector localpos;
vector global_pos;
key simq;
key novum_creator = "6ff03b8a-2879-4d75-8e0e-40e30c537368";
// ns - basic stuff
key unit_uuid;
integer unit_serial;
key faction; // UUID of the current group of this controller
vector color;
vector color_default = <0.500000,0.500000,1.000000>; // Aurelia = <0.500000,0.500000,1.000000> , Dunya = <1.000000,0.000000,0.000000>
// ns - power manager
float power; // power=battery_level/battery_capacity
string power_rate_str; // float->string power_rate conversion
string power_state; // <on/off>
float power_rate; // global rate for powermanager
key power_port; 
float battery_level;
float battery_capacity; 
string battery_type = "(internal)";
integer batchan1;
integer batchan2; // battery send & battery receive channels
integer power_alert_cd=60; // cooldown between battery level alert
integer ischarging;
// ns - device manager
key device_handle;
key device_collar;
key device_battery;
key device_shield;
key device_titler;
key device_wristband;
// ns - combat stuff
float fan_speed;
float integrity_level;
float integrity_capacity = 100.000000; // need to read this from a HEV suit
float health_level;
float health_capacity = 100.000000; // humans are always 100HP and cyborgs add integrity on top of this
float temperature;
integer kill_cooldown=20; // cooldown before resurrection
integer ishealing;
integer isrepairing;
integer emi_type;
float emi_duration;
float hit; // global hit for healthmanager
float basetemp=36.600000; // base temperature for the HEV suit controller
// debug stuff
integer time_dilation;
integer region_fps;
integer debug_output = 0;
string button_mode = "debug"; // default is debug
// system infos
key system_owner = "cc985f46-8c37-4f64-9e1d-3cab2099a425"; // Aurelia = cc985f46-8c37-4f64-9e1d-3cab2099a425 , Nyabloody = 9bbd68f6-5a11-4501-a193-76f9a28e06cb
string system_model = "Human"; // Human/F, Human/M, Cyborg/F, Cyborg/M, ...
string system_gender = "hers,her,she,her,herself,female";
string system_authority = "Aetheria_Temple";
string system_shortname = "ATLE"; // this will be shown instead of Companion
string system_version = "1.5.2"; // this will be shown instead of 8.6.4
string system_fullname = "Aetheria Temple Lightbus Emulator";
string system_build = "2023-11-26";
key system_author = "cc985f46-8c37-4f64-9e1d-3cab2099a425"; 
string system_vendor = "Aetheria Temple Corporation";
string system_name;
string combat_name = "Kombat"; // this will be shown instead of ATOS
string combat_version = "0.3.2"; // this will be shown instead of 12.0.26

set_lights(float level) {
    //llSetLinkColor(LINK_THIS, color * level, ALL_SIDES);
}

group_key() { // Function to get group uuid from this object
   key thisPrim = llGetKey();
   list objectDetails = llGetObjectDetails(thisPrim, [OBJECT_GROUP]);
   key objectGroup = llList2Key(objectDetails, 0);

   if (objectGroup != NULL_KEY)
      faction = objectGroup;   
}

debug_mode() {
    if (debug_output == 0)
    {
       debug_output = 1;
       llOwnerSay("Debug output enabled.");
    }
    else if (debug_output == 1)
    {
       debug_output = 0;
       llOwnerSay("Debug output disabled.");
    }    
}

console_debug(string out_msg, integer chan) {
    if(debug_output == 1)
    {
        string cn;
        if(chan==channel_lights){
            cn = "LIGHTBUS";
        }else if(chan==channel_public){
            cn = "PUBLIC";
        }else if(chan==channel_private){
            cn = "PRIVATE";
        }else if(chan==channel_acs){
            cn = "ACS";
        }else if(chan==0){
            cn = "LINK";
        }else{
            cn = "N/A";    
        }
            
        if(out_msg != "")
            llOwnerSay("[DEBUG]["+(string)chan+" ("+cn+")] "+out_msg);
    } 
}

string FormatDecimal(float number, integer precision) {     
    float roundingValue = llPow(10, -precision)*0.5;
    float rounded;
    if (number < 0) rounded = number - roundingValue;
    else            rounded = number + roundingValue;
 
    if (precision < 1) // Rounding integer value
    {
        integer intRounding = (integer)llPow(10, -precision);
        rounded = (integer)rounded/intRounding*intRounding;
        precision = -1; // Don't truncate integer value
    }
 
    string strNumber = (string)rounded;
    return llGetSubString(strNumber, 0, llSubStringIndex(strNumber, ".") + precision);
}

float String2Float(string ST) {
    list nums = ["0","1","2","3","4","5","6","7","8","9",".","-"];
    float FinalNum = 0.0;
    integer idx = llSubStringIndex(ST,".");
    if (idx == -1)
    {
        idx = llStringLength(ST);
    }
    integer Sgn = 1;
    integer j;
    for (j=0;j< llStringLength(ST);j++)
    {
        string Char = llGetSubString(ST,j,j);
        if (~llListFindList(nums,[Char]))
        {
            if((j==0) && (Char == "-"))
            {
                Sgn = -1;
            }
            else if (j < idx)
            {
                FinalNum = FinalNum + (float)Char * llPow(10.0,((idx-j)-1));
            }
            else if (j > idx)
            {
                FinalNum = FinalNum + (float)Char * llPow(10.0,((idx-j)));
            }
        }
    }
    return FinalNum * Sgn;
}

chronometer()
{
     time_dilation = llFloor(llGetRegionTimeDilation() * 100);
     region_fps = llFloor(llGetRegionFPS());   
}

movemanager()
{ 
    float speed = llVecMag(llGetVel());
    if(speed > 1)
    {
        power_rate = speed * 100;
        ischarging = FALSE;
        powermanager(power_rate, FALSE);
    }
}

radmanager(integer type, float duration)
{ 
    string typestring;
    
    if(type > 0)
    {
        if(type==1)typestring="M";
        if(type==2)typestring="S";
        if(type==4)typestring="C";
        if(type==8)typestring="Y";
        if(type==16)typestring="N";
        else typestring="MSCYN";
        
        if(duration > 0)
        {
            llRegionSayTo(llGetOwner(), channel_lights, "interference-state "+typestring);
            --emi_duration;
        }
        else
        {
           llRegionSayTo(llGetOwner(), channel_lights, "interference-state "); 
           emi_type = 0;
           emi_duration = 0;    
        }
    }
    else
    {
       llRegionSayTo(llGetOwner(), channel_lights, "interference-state "); 
       emi_type = 0;
       emi_duration = 0;    
    }
}

coolmanager()
{
    temperature = basetemp;
    llSay(channel_lights, "temperature "+(string)temperature);
    
    if(temperature >= 60)
    {
       fan_speed = 100;    
    } 
    else if(temperature >= 40 & temperature <= 59)
    {
       fan_speed = 50;   
    }
    else if(temperature >= 20 & temperature <= 39)
    {
       fan_speed = 25;  
    }
    else if(temperature <= 19)
    {
       fan_speed = 0;       
    }
    
    llSay(channel_lights, "fan "+(string)fan_speed);    
}

powermanager(float rate, integer charging)
{
    //if(device_battery==NULL_KEY) power_state=="off"; battery_level=0;
    
    if(power>0 && power_state=="on")
    {
        if(power>0.499 && power<0.5)
        {
            if(power_alert_cd==60)
            {
                llWhisper(0,"/me battery level under 50%.");
            }
            else if(power_alert_cd==0)
            {
                power_alert_cd=60; 
            }
        }
        if(power>0.149 && power<0.15)
        {
            if(power_alert_cd==60)
            {
                llWhisper(0,"/me battery level under 15%.");
            }
            else if(power_alert_cd==0)
            {
                power_alert_cd=60; 
            }
        }
        if(battery_level >= rate && charging == FALSE)
        {
            ischarging = FALSE;
            power_rate_str = (string)llFloor(rate); 
            battery_level = battery_level - rate;
            if(battery_level < 0)
            {
               battery_level = 0.000000;
               power_state = "off";
            }
            llMessageLinked(LINK_SET,POWER_RATE,(string)power_rate,"");
        }
        if(battery_level <= battery_capacity && charging == TRUE)
        {
            ischarging = TRUE;
            power_rate_str = (string)llFloor(0-rate);
            battery_level = battery_level + rate;
            if(battery_level > battery_capacity)
            {
               battery_level = battery_capacity;
            }
        }
        llSay(channel_lights, "rate "+power_rate_str); // send current power rate over lightbus
        
        power = battery_level/battery_capacity;
        llSay(channel_lights, "power "+(string)power); // send current power level over lightbus
    }
    else if(power_state=="off")
    {
        //if(device_battery==NULL_KEY) battery_capacity=0;
        
        if(battery_level <= battery_capacity && charging == TRUE)
        {
            ischarging = TRUE;
            power_rate_str = (string)llFloor(0-rate);
            battery_level = battery_level + rate;
            if(battery_level > battery_capacity)
            {
               battery_level = battery_capacity;
            }
        }
    }

    llRegionSayTo(device_battery, batchan2, "="+(string)battery_level);
    
    //llMessageLinked(LINK_SET,POWER_LEVEL,(string)battery_level,"");
    //llMessageLinked(LINK_SET,POWER_CAPACITY,(string)battery_capacity,"");
    
    //temperature = llFloor(llFrand(basetemp));
    //llSay(channel_lights, "temperature "+(string)temperature);
    //coolmanager();
    
    --power_alert_cd;
}

healthmanager(key agent, float hit, integer heal)
{
    if(heal==FALSE)
    {
       if(hit > 0)
       {
            health_level = health_level - hit;
            llTriggerSound("hurt",0.5);
            
            if(health_level <= 0)
            {
               health_level = 0;
               
               string agent_name = llGetDisplayName(agent);
               if(agent_name!="")
               {
                   llStartAnimation("s_dead");
                   llTriggerSound("death",0.5);
                   llWhisper(0,"/me was killed by "+agent_name);
                   llOwnerSay("@setdebug_renderresolutiondivisor:64=force");
                   llSleep(20.0);
                   health_level=health_capacity/10;
                   llTriggerSound("hevhealok",0.5);
                   llOwnerSay("Vital signs critical. Seek medical assistance immediately.");
                   llOwnerSay("@setdebug_renderresolutiondivisor:1=force");
                   llStopAnimation("s_dead");
               }
               else
               {
                   llStartAnimation("s_dead");
                   llTriggerSound("death",0.5);
                   llWhisper(0,"/me was killed by unknown force.");
                   llOwnerSay("@setdebug_renderresolutiondivisor:64=force");
                   llSleep(20.0);
                   health_level=health_capacity/10;
                   llTriggerSound("hevhealok",0.5);
                   llOwnerSay("Vital signs critical. Seek medical assistance immediately.");
                   llOwnerSay("@setdebug_renderresolutiondivisor:1=force");
                   llStopAnimation("s_dead");
               }
            }  
        }
        else if(hit < 0)
        {
            if(health_level <= health_capacity)
            {
               health_level = health_level + hit;
               
               if(health_level >= health_capacity)
               {
                    health_level = health_capacity;
                    llTriggerSound("hevhealok",0.5);
               }
            }      
        }  
    }
    else if(heal==TRUE)
    {
        if(health_level <= health_capacity)
        {
           health_level = health_level + hit;
           
           if(health_level >= health_capacity)
           {
                health_level = health_capacity;
                //llTriggerSound("hevhealok",0.5);
           }
        }    
    }
    
    llRegionSayTo(llGetOwner(),channel_lights, "health "+(string)health_level); // this is for vostoff titler and need to be replaced by the command below
    llRegionSayTo(llGetOwner(),channel_lights, "integrity "+(string)(health_level/100)+" 1 "+(string)(health_capacity/100));
}

send_color(key id)
{
    if(id!=llGetOwner())
    {
        llRegionSayTo(id, channel_lights, "color "+ (string)color_msg); // Send color on lightbus
        llRegionSayTo(id, channel_lights, "color-2 "+ (string)color_msg); // Send color-2 on lightbus
        llRegionSayTo(id, channel_lights, "color-3 "+ (string)color_msg); // Send color-3 on lightbus
        llRegionSayTo(id, channel_lights, "color-4 "+ (string)color_msg); // Send color-4 on lightbus
    }
    else
    {
        llSay(channel_lights, "color "+ (string)color_msg); // Send color on lightbus
        llSay(channel_lights, "color-2 "+ (string)color_msg); // Send color-2 on lightbus
        llSay(channel_lights, "color-3 "+ (string)color_msg); // Send color-3 on lightbus
        llSay(channel_lights, "color-4 "+ (string)color_msg); // Send color-4 on lightbus   
    }
}

restart()
{
    llResetOtherScript("nsle_combat");
    llResetOtherScript("_coil");
    llResetOtherScript("_flicker-tetra-autoconf");
    llResetScript();   
}

default
{  
    state_entry()
    {
        unit_uuid = llGetOwner();
        system_owner = llGetOwner();
        system_name = llGetObjectName();
        unit_serial = llAbs((integer)("0x" + llGetSubString( (string) unit_uuid, 0, -1) ) + 123); // Vostoff serial generator
        
        channel_lights = -1 - (integer)("0x" + llGetSubString( (string) unit_uuid, -7, -1) ) + 106; // NS official lightbus generator
        channel_private = -unit_serial; // Unit remote channel
        channel_acsi = -1 - (integer)llGetSubString((string)unit_serial,-4,-1) - llFloor(llFrand(1.0)*1000);
        channel_rlvhook = (integer)llGetSubString((string)unit_serial,-3,-1);
        
        //battery_level = battery_capacity;
        //power = battery_level/battery_capacity;
        //power_state = "on";
        //power_rate = 150.000000;
        //ischarging = FALSE;
        //powermanager(power_rate, ischarging);
        
        integrity_level = integrity_capacity;
        health_level = health_capacity;
    
        coolmanager();

        healthmanager(NULL_KEY, 0, FALSE);
        
        llOwnerSay("Cold boot sequence initiated...");
        
        llSleep(1.0);
        
        llOwnerSay("Initializing communication channels...");
        
        llListen(channel_lights, "", "", "");
        llListen(channel_public, "", "", "");
        llListen(channel_private, "", "", "");
        llListen(channel_pong, "", "", "");
        llListen(channel_ping, "", "", "");
        llListen(channel_identify, "", "", "");
        llListen(channel_acs, "", "", "");
        llListen(channel_acsi, "", "", "");
        llListen(channel_rlvrc, "", "", "");
        llListen(55, "", "", ""); // Default NS devices channel
        llListen(2, "", "", ""); // Custom channel for commands
        llListen(channel_rlvhook,"","",""); // Rlv relay chat
        llListen(-900000, "_Event Horizon", NULL_KEY, "");
        
        //llRequestPermissions(llGetOwner(), PERMISSION_TELEPORT);
        llRequestPermissions(llGetOwner(), PERMISSION_TRIGGER_ANIMATION);
    
        llSleep(1.0);
        
        llOwnerSay("Probing devices...");
        
        llRegionSayTo(llGetOwner(), channel_lights, "probe");
        llRegionSayTo(llGetOwner(), channel_public, "ping "+(string)channel_pong);
        
        llSleep(1.0);
        
        llOwnerSay("Initializing colors...");
        
        color_msg = (string)color.x+" "+(string)color.y+" "+(string)color.z;
        set_lights(1.0); // Set color to our prims
        
        llSleep(1.0);
        
        //llOwnerSay("Serial: "+(string)unit_serial+"\nLightbus: "+(string)channel_lights+"\nBattery: "+(string)llFloor(battery_capacity/1000)+" kJ\nHealth: "+(string)llFloor(health_capacity)+" HP");
        
        llSleep(1.0);
        
        llOwnerSay("Welcome "+llGetDisplayName(llGetOwner())+"! You are running "+system_fullname+"/"+system_version+" by Dr. secondlife:///app/agent/"+(string)system_author+"/about.");

        llSetTimerEvent(1);
    }
    
    attach(key a)
    {
        if (a != NULL_KEY)
        {
            llOwnerSay("Waking up from sleep mode...");
            
            llSleep(1.0);
            
            llOwnerSay("Probing devices...");
            
            llRegionSayTo(llGetOwner(), channel_lights, "probe");
            llRegionSayTo(llGetOwner(), channel_public, "ping "+(string)channel_pong);
            
            llSleep(1.0);

            llSetTimerEvent(1);
        }    
    }
    
    changed(integer c)
    {
       if (c & CHANGED_OWNER)
       {
           llOwnerSay("User changed. Resetting system...");
           llSleep(1.0);
           restart();
       }
       if (c & CHANGED_TELEPORT)
       {
           llOwnerSay("@attachover:~NyaStuff/warp=force");
           llWhisper(360,"ACS,interfere,CY,2.000000,0.5"); 
           llOwnerSay("Teleportation completed.");
           float tpenergy = 300000;
           llRegionSayTo(device_battery, batchan2, "="+(string)(battery_level-tpenergy));
           llSleep(5.0);
           llOwnerSay("@detach:~NyaStuff/warp=force");
           //llOwnerSay("Teleporation cooldown finished."); 
       }
    }
    
    touch_start(integer total_number)
    {
        integer i;
        for (i = 0;i < total_number;i += 1)
        {
            if(llDetectedKey(i) == llGetOwner())
            {
               if(button_mode=="debug")
               {
                   debug_mode();
               }
            }
        }
    }
    
    listen(integer channel, string name, key id, string message)
    {
        // NS LIGHTBUS CHANNEL
        if(channel==channel_lights)
        {
            light_msg = message;
            console_debug(name+"|"+message, channel);
            if(llGetSubString(light_msg, 0, 5) == "color ")
            {
                 list rgb = llParseString2List(llGetSubString(message, 6, -1), [" "], []);
                 color = <llList2Float(rgb, 0), llList2Float(rgb, 1), llList2Float(rgb, 2)>; // Color as vector
                 color_msg = (string)String2Float(llList2String(rgb, 0))+" "+(string)String2Float(llList2String(rgb, 1))+" "+(string)String2Float(llList2String(rgb, 2)); // Color color as string
                 set_lights(1.0); // Apply color to our prims
            }
            else if(llGetSubString(light_msg, 0, 6) == "color-q")
            {
                send_color(id); // Send color to device request
            }
            else if(llGetSubString(light_msg, 0, 3) == "ping")
            {
                llRegionSayTo(id, channel_lights, "pong");
            }
            else if(llGetSubString(light_msg, 0, 6) == "power-q")
            {
                if(power>0)
                {
                    llSay(channel_lights, "on");
                    llSay(channel_lights, "power "+(string)power);
                }
                else
                {
                    llSay(channel_lights, "off");
                    llSay(channel_lights, "power 0"); 
                }
            }
            /* else if(light_msg == "on")
            {
                if(power>0)
                {
                    llSay(channel_lights, "power "+(string)power); 
                    set_lights(1.0);
                    llSetTimerEvent(1);
                }
                else
                {
                   set_lights(0.1);
                   llSetTimerEvent(0);
                }
                
            }
            else if(light_msg == "off")
            {
                set_lights(0.1);
                llSetTimerEvent(0);
            } */
            else if(llGetSubString(light_msg, 0, 3) == "add ")
            {
                /* if(llGetOwnerKey(id)!=llGetOwner())
                {
                   if(llGetOwnerKey(id)!="9bbd68f6-5a11-4501-a193-76f9a28e06cb") // Aetheria
                   {
                       llRegionSayTo(llGetOwnerKey(id), 0, "Your device has been rejected by this system.");
                       return;          
                   }
                   else if(llSameGroup(id)==FALSE)
                   {
                       llRegionSayTo(llGetOwnerKey(id), 0, "Your device has been rejected by this system.");
                       return;     
                   }   
                } */
                
                llRegionSayTo(id, channel_lights, "add-confirm");
                llRegionSayTo(id, channel_lights, "name "+system_name);
                
                string device = llGetSubString(light_msg, 4, -1);
                
                if(llGetSubString(device,0,6)=="titler ")
                {
                    device_titler = id;
                }
                else if (llGetSubString(device,0,6)=="shield ")
                {
                    device_shield = id;
                }
                else if (llGetSubString(device,0,6)=="handle ")
                {
                    device_handle = id;
                }
                else if (llGetSubString(device,0,7)=="battery ")
                {
                    device_battery = id;
                    battery_type = llKey2Name(device_battery);
                }
                else if (llGetSubString(device,0,9)=="wristband ")
                {
                    device_wristband = id;
                }
                
                llOwnerSay("Device "+llKey2Name(id)+" ("+device+") connected to lightbus.");
            }
            else if(llGetSubString(light_msg, 0, 4) == "load ")
            {
                list fullcmd = llParseString2List(message, [" "], []);
                string cmd = llList2String(fullcmd, 0);
                string device = llList2String(fullcmd, 1);
                string task = llList2String(fullcmd, 2);
                float watt = llList2Float(fullcmd, 3);
                
                llOwnerSay("Device "+device+" added task "+task+" with load "+(string)watt+" W");
            }
            else if(llGetSubString(light_msg, 0, 11) == "add-command ")
            {
                /* if(llGetOwnerKey(id)!=llGetOwner())
                {
                   if(llGetOwnerKey(id)!="9bbd68f6-5a11-4501-a193-76f9a28e06cb") // Aetheria
                   {
                       llRegionSayTo(llGetOwnerKey(id), 0, "Your device has been rejected by this system.");
                       return;          
                   }
                   else if(llSameGroup(id)==FALSE)
                   {
                       llRegionSayTo(llGetOwnerKey(id), 0, "Your device has been rejected by this system.");
                       return;     
                   }   
                } */
                
                string command = llGetSubString(light_msg, 12, -1);
                string device = llKey2Name(id);
                llOwnerSay("Device "+device+" registered command "+command+" on the system.");
            }
            else if(llGetSubString(light_msg, 0, 6) == "remove ")
            {
                string device = llGetSubString(light_msg, 7, -1);
                llOwnerSay("Device "+device+" removed from lightbus.");
            }
            else if(llGetSubString(light_msg, 0, 13) == "weapon active ")
            {
                llRegionSayTo(id, channel_lights, light_msg);
                //llOwnerSay("Weapon activated."); 
            }
            else if(llGetSubString(light_msg, 0, 14) == "weapon inactive")
            {
                llRegionSayTo(id, channel_lights, light_msg);
                //llOwnerSay("Weapon deactivated.");
            }
            else if(llGetSubString(light_msg, 0, 11) == "weapon info ")
            {
                llRegionSayTo(id, channel_lights, light_msg);
            }
            else if(llGetSubString(light_msg, 0, 13) == "weapon reload")
            {
                float weapon_charge = llFrand(10.0);
                llRegionSayTo(id, channel_lights, "weapon charge "+(string)weapon_charge);
                //llOwnerSay("Weapon reloading.");
            }
            else if(llGetSubString(light_msg, 0, 10) == "port power ")
            {
                power_port = (key)llGetSubString(light_msg, 11, -1);
                llRegionSayTo(llGetOwner(), channel_lights, "port-real power "+(string)power_port);
            }
            else if(light_msg=="port-connect power")
            {
                llRegionSayTo(id, channel_lights, "port-real power "+(string)power_port);
            }
            else if(light_msg=="port-disconnect power" && id==power_port)
            {
                llRegionSayTo(id, channel_lights, "port-real power "+(string)llGetKey());
                llRegionSayTo(llGetOwner(), channel_lights, "port-real power "+(string)llGetKey());
            }
            else if(llGetSubString(light_msg, 0, 8) == "internal ")
            {
                string icommand = llGetSubString(light_msg, 9, -1);
            }
            else if(llGetSubString(light_msg, 0, 9) == "sentinel-q")
            {
                llRegionSayTo(id, channel_lights, "health "+(string)health_level);
                llRegionSayTo(id, channel_lights, "temperature "+(string)temperature);
                //llRegionSayTo(id, channel_lights, "version "+system_shortname+"/"+system_version);
                //llRegionSayTo(id, channel_lights, "model "+system_model);
            }
            else if(llGetSubString(light_msg, 0, 8) == "conf-get ")
            {  
                list conflist = llParseString2List(llGetSubString(message, 9, -1), ["\n"], []);
                if(llList2String(conflist,0)=="boot.model") llRegionSayTo(id, channel_lights, "conf boot.model "+system_model);
                if(llList2String(conflist,1)=="boot.vendor") llRegionSayTo(id, channel_lights, "conf boot.vendor "+system_vendor);
                if(llList2String(conflist,3)=="boot.name") llRegionSayTo(id, channel_lights, "conf boot.name "+system_name);
                if(llList2String(conflist,4)=="gender.physical") llRegionSayTo(id, channel_lights, "conf gender.physical "+system_gender);
                if(llList2String(conflist,5)=="performer.$version") llRegionSayTo(id, channel_lights, "conf performer.$version "+system_version);
            }
            else if(light_msg == "connected battery")
            { 
                batchan1 = -649930162;
                batchan2 = -649930835;
                llListen(batchan1, "", "", "");
                //llListen(batchan2, "", "", "");
                llRegionSayTo(id, channel_lights, "channel "+(string)batchan1);
                llRegionSayTo(id, channel_lights, "channel "+(string)batchan2);
                power_state = "on";
                powermanager(power_rate, ischarging);
            }
            else
            {
                //llRegionSayTo(id, 0, "Not implemented.");
                //llRegionSayTo(llGetOwnerKey(id), 0, "Not implemented.");
            }
        }
        
        // NS PRIVATE/REMOTE CHANNEL
        else if(channel==channel_private)
        {
            prv_msg = message;
            console_debug(name+"|"+message, channel);
            if(llGetSubString(prv_msg, 0, 4) == "about")
            {
               llRegionSayTo(llGetOwnerKey(id), 0,"Aetheria Temple Lightbus Emulator - System Information \nVendor: Dr. secondlife:///app/agent/"+(string)system_author+"/about \nModel: "+system_model+" \nName: "+llGetObjectName()+" \nFirmware version: "+system_version+" \nBuild date: "+system_build+" \nController serial number: "+(string)unit_serial+" \nAuthority: "+system_authority+"");
                /*
                    Chassis vendor: ██████
                    Chassis model: Cyber Succubus Automaton 3.0
                    Chassis serial number: 991-15-9751
                    Devices connected to oXq.205.8i:
                     - shield (API.Multi//Cube)
                     - sign (CSA/3 Aetheria (qubit))
                     - horns (Aetheria (horns))
                     - tail (Aetheria (tail))
                     - battery (NS uRTG Radioisotope Power Cell 13-0002-H)
                     - collar (Aetheria (collar))
                     - HUD (CSA/3 Aetheria (HUD))
                     - chassis (CSA/3 Aetheria (chassis))
                    8 device(s) total.
                    Device commands:
                     - API (shield)
                     - mood (sign)
                     - sign (sign)
                     - horns (horns)
                     - tail (tail)
                     - kinematics (chassis)
                    6 command(s) total.
                    Users:
                     - Nyabloody  (owner)
                     - Aurelia Vostöff (aureliavostoff)  (owner)
                     - Dothea (DotheaMoonlight)  (manager)
                    3 user(s) total.
                  */
            }
            else if(llGetSubString(prv_msg, 0, 4) == "power")
            {
                  llRegionSayTo(llGetOwnerKey(id), 0,"Available power: "+(string)llFloor(battery_level/1000)+"/"+(string)llFloor(battery_capacity/1000)+" kJ \nPower source: "+battery_type+" \nPower draw rate: "+power_rate_str+" W \nEstimated remaining charge time: \nAverage real power usage (last 10 seconds): \n\nEnabled subsystems: move, teleport, rapid, voice, receiver, transmitter, GPS, identify \nAdditional loads: ");
               /*
                    Estimated remaining charge time: 1 day, 3:58:31
                    Average real power usage (last 10 seconds): 840 W
                    Additional loads: cooling (5 W total)
                  */
            }
            else if(message == "probe")
            {
                llOwnerSay("Reprobing...");
                llSleep(1.0);
                llRegionSayTo(llGetOwner(), channel_lights, "probe");
                llRegionSayTo(llGetOwner(), channel_public, "ping "+(string)channel_pong);      
            }
            else if(message == "help")
            {
                llRegionSayTo(llGetOwnerKey(id), 0,"Welcome to ATLE!

This command is ATLE's on-board help service. If you would like to make a hard copy of this information, it can be found in the `manual` file inside your controller's system memory.

Basic commands:

\"help\", \"about\", \"power\", \"probe\", \"color\", \"scan\", \"on\", \"off\", \"device\".");      
            }
            else if(llGetSubString(prv_msg, 0, 5) == "color ")
            {
                list rgb = llParseString2List(llGetSubString(message, 6, -1), [" "], []);
                color = <llList2Float(rgb, 0), llList2Float(rgb, 1), llList2Float(rgb, 2)>; // Color as vector
                color_msg = (string)String2Float(llList2String(rgb, 0))+" "+(string)String2Float(llList2String(rgb, 1))+" "+(string)String2Float(llList2String(rgb, 2)); // Color color as string
                set_lights(1.0); 
                send_color(llGetOwner()); // Send color on lightbus for all attached devices
                llRegionSayTo(llGetOwnerKey(id), 0, "Updating color."); // Tell operator that color has changed
            }
            else if(llGetSubString(prv_msg, 0, 5) == "sxdwm ")
            {
                if(llGetSubString(prv_msg, 6, -1) == "disconnect")
                {
                    llRegionSayTo(llGetOwnerKey(id), 0, "Goodbye.");
                }
                else if(llGetSubString(prv_msg, 6, -1) == "connect "+(string)llGetOwner())
                {
                    //llRegionSayTo(llGetOwnerKey(id), 0, "Not implemented.");
                    console_debug(name+"|NOT IMPLEMENTED|"+message, channel);
                }  
            }
            else if(llGetSubString(prv_msg, 0, 3) == "scan")
            {
                  if(llGetSubString(prv_msg, 4, -1) == "osnow")
                  {
                      llRegionSay(channel_public, "ping "+(string)channel_pong);     
                  }
                  else if(llGetSubString(prv_msg, 4, -1) == "atosnow")
                  {
                      llRegionSay(channel_public, "identify "+(string)channel_identify);  
                  }    
            }
            else if(llGetSubString(prv_msg, 0, 6) == "charge ")
            {
                /* float add = (float)llGetSubString(pub_msg, 7, -1);
                power_rate = add*1000;
                ischarging = TRUE;
                powermanager(power_rate, ischarging); */
                
                float add = String2Float(llGetSubString(prv_msg, 7, -1));
                power_rate = add*1000;
                ischarging = TRUE;
                powermanager(power_rate, ischarging);
            }
            else if(llGetSubString(prv_msg, 0, 6) == "repair ")
            {
                if(llGetSubString(prv_msg, 7, -1) == "stop")
                {
                    llWhisper(0, "/me automatically disconnects from "+name);
                }
                else
                {
                    float integrity_add = (float)llGetSubString(prv_msg, 7, -1);
                    if(integrity_level <= integrity_capacity)
                    {
                       integrity_level = integrity_level + integrity_add*100;
                       if(integrity_level > integrity_capacity)
                       {
                            integrity_level = integrity_capacity;
                       }
                    }
                    float integlevel = integrity_level/100;
                    llRegionSayTo(id, channel_public, "identification "+(string)integlevel);
                }
            }
            else if(prv_msg == "on")
            {
                if(device_battery==NULL_KEY)
                {
                    llRegionSayTo(id, 0, "CANNOT BOOT. Battery is missing.");
                }
                else
                {
                   power_state = "on";
                   powermanager(power_rate, ischarging);
                   llSay(channel_lights, "on");
                   set_lights(1.0);     
                }
            }
            else if(prv_msg == "off")
            {
                power_state = "off";
                powermanager(power_rate, ischarging);
                llSay(channel_lights, "off");
                set_lights(0.1);
            }
            else if(llGetSubString(prv_msg, 0, 6) == "device ")
            {
                  llOwnerSay(llGetSubString(prv_msg, -6, -1));
                  
                  if(llGetSubString(prv_msg, 7, -1) == "probe")
                  {
                      llRegionSayTo(llGetOwner(), channel_lights, "probe");
                      llOwnerSay("[TEST] (LIGHTBUS) Reprobing...");
                      llRegionSayTo(id, 0, "[TEST] (LIGHTBUS) Reprobing...");    
                  }
                  else if(llGetSubString(prv_msg, -7, -1) == " remove")
                  {
                      list zcommand = llParseString2List(prv_msg, [" "], []);
                      string zdevicename = llList2String(zcommand, 1);
                      integer zremoved;
                      key zdevice;
                      
                      if(zdevicename=="titler")
                      {
                          zdevice = device_titler;
                          zremoved = TRUE;
                      }
                      else if(zdevicename=="shield")
                      {
                          zdevice = device_shield;
                          zremoved = TRUE;
                      }
                      else if(zdevicename=="handle")
                      {
                          zdevice = device_handle;
                          zremoved = TRUE;
                      }
                      else if(zdevicename=="battery")
                      {
                          zdevice = device_battery;
                          zremoved = TRUE;
                      }
                      else if(zdevicename=="wristband")
                      {
                          zdevice = device_wristband;
                          zremoved = TRUE;
                      }
                      else
                      {
                          zdevice = NULL_KEY;
                          zremoved = FALSE;    
                      }
                
                      if(zremoved==TRUE)
                      {   
                         llOwnerSay("[TEST] (LIGHTBUS) Removed "+llKey2Name(zdevice)+" from device manager.");
                         llRegionSayTo(id, 0, "[TEST] (LIGHTBUS) Removed "+llKey2Name(zdevice)+" from device manager.");   
                      }
                      else
                      {
                         llOwnerSay("[TEST] (LIGHTBUS) Couldn't remove device.");
                         llRegionSayTo(id, 0, "[TEST] (LIGHTBUS) Couldn't remove device. Maybe this device UUID is not registered on this system?");   
                      }
                  }    
            }
            else
            {
                //llRegionSayTo(id, 0, "Not implemented.");
                //llRegionSayTo(llGetOwnerKey(id), 0, "Not implemented.");
                console_debug(name+"|NOT IMPLEMENTED|"+message, channel);
            }
        }
        
        // NS PUBLIC CHANNEL
        else if(channel==channel_public)
        {
            pub_msg = message;
            console_debug(name+"|"+message, channel);
            if(llGetSubString(pub_msg, 0, 4) == "ping ")
            {
                integer serial = unit_serial;
                string os = system_shortname+"/"+system_version;
                key owner = system_owner;
                string model = system_model;
                string authority = system_authority;
                
                integer ping_channel = (integer)llGetSubString(pub_msg, 5, -1); // Get ping channel
                string ping_answer = (string)serial+" "+os+" "+(string)owner+" "+model+" "+authority; // Message to send to ping channel
                
                if(name != "NS Remote Console")
                {
                    llRegionSayTo(id, ping_channel, ping_answer); // Send pong to ping channel
                }
                else
                {
                    llRegionSayTo(llGetOwnerKey(id), ping_channel, ping_answer); // Send pong to ping channel
                }
            }
            else if(llGetSubString(pub_msg, 0, 8) == "identify ")
            {
                float integrity = integrity_level/100;
                float temp_celsius = temperature; 
                integer repairing = 0; 
                integer serial = unit_serial; 
                string atos_name = combat_name;
                string atos_version = combat_version; 
                group_key(); 
                
                channel_identify = (integer)llGetSubString(pub_msg, 9, -1);// Get ping channel
                string ident_answer = "identification "+(string)integrity+" "+(string)temp_celsius+" "+(string)repairing+" "+(string)serial+" "+atos_name+" "+atos_version+" "+(string)faction;// Message to send to ping channel
                
                if(name != "NS Remote Console")
                {
                    llRegionSayTo(id, channel_identify, ident_answer); // Send pong to ping channel 
                }
                else
                {
                    llRegionSayTo(llGetOwnerKey(id), channel_identify, ident_answer); // Send pong to ping channel  
                }
            }   
            else if(llGetSubString(pub_msg, 0, 6) == "repair ")
            {
                if(llGetSubString(pub_msg, 7, -1) == "stop")
                {
                    //llWhisper(0, "/me automatically disconnects from "+name);
                }
                else
                {
                    float integrity_add = (float)llGetSubString(pub_msg, 7, -1);
                    if(integrity_level <= integrity_capacity)
                    {
                       integrity_level = integrity_level + integrity_add*100;
                       if(integrity_level > integrity_capacity)
                       {
                            integrity_level = integrity_capacity;
                       }
                    }
                    float integlevel = integrity_level/100;
                    llRegionSayTo(id, channel_public, "identification "+(string)integlevel);
                }
            }
            else if(llGetSubString(pub_msg, 0, 6) == "charge ")
            {
                if(llSameGroup(id)==TRUE)
                {
                    float add = String2Float(llGetSubString(pub_msg, 7, -1));
                    power_rate = add*1000;
                    ischarging = TRUE;
                    powermanager(power_rate, ischarging);
                }
            }
            else if(llGetSubString(pub_msg, 0, 4) == "heal ")
            {
                float health_add = (float)llGetSubString(pub_msg, 5, -1);
                healthmanager(NULL_KEY, health_add, TRUE);
            }
            else
            {
                //llRegionSayTo(id, 0, "Not implemented.");
                //llRegionSayTo(llGetOwnerKey(id), 0, "Not implemented.");
                console_debug(name+"|NOT IMPLEMENTED|"+message, channel);
            }
        }
        
        // PONG ANSWER CHANNEL
        else if(channel==channel_pong)
        {
            pong_msg = message;
            llOwnerSay(name+" secondlife:///app/agent/"+(string)llGetOwnerKey(id)+"/inspect "+pong_msg);
        }
        
        // IDENT ANSWER CHANNEL
        else if(channel==channel_identify)
        {
            console_debug(name+"|"+message, channel);
        }
        
        // ACS PUBLIC CHANNEL
        /* else if(channel==channel_acs)
        {
            console_debug(name+"|"+message, channel);
            acs_msg = message;
            if(acs_msg == "ACS,hello,CHARGER")
            {
                //string welcome_answer = "ACS,welcome,ccu,ver=AT:LightEmu:"+system_version+",remoteok=1,power=EL";
                string welcome_answer = "NS,welcome,"+llGetObjectName()+","+system_version;
                llRegionSayTo(id, channel_acs, welcome_answer);
            }
            else if(acs_msg == "ACS,interface,CHARGER")
            {
                channel_acsi = -1 - (integer)llGetSubString((string)unit_serial,-4,-1) - llFloor(llFrand(1.0)*1000);
                string acsi_answer = "ACS,interface,"+(string)channel_acsi;
                llRegionSayTo(id, channel_acs, acsi_answer);

                string pt_answer = "ACS,powertype:EL";
                integer maxcharge = llFloor(battery_capacity);
                string mc_answer = "ACS,maxcharge:"+(string)maxcharge;
                string ud_answer = "ACS,unitdisconnect:1";
                
                llRegionSayTo(id, channel_acsi, pt_answer);
                llRegionSayTo(id, channel_acsi, mc_answer);
                llRegionSayTo(id, channel_acsi, ud_answer);
                
                llWhisper(0,"/me connects to the "+name);
            }
            else if(acsi_msg == "ACS,disconnect:")
            {
                llRegionSayTo(id, channel_acsi, "ACS,goodbye:");
                llWhisper(0, "/me automatically disconnects from "+name);
            }            
        } */
        
        // ACS PRIVATE CHANNEL
        /* else if(channel==channel_acsi)
        {
            console_debug(name+"|"+message, channel);
            acsi_msg = message;
            if(acsi_msg == "ACS,chargersummary:")
            {
                //integer poweracs = llFloor(battery_level/battery_capacity);
                integer poweracs = llFloor(power*100);
                integer powered = 1;
                integer powertofull = llFloor(battery_capacity-battery_level);
                string chargesum_answer = "ACS,chargersummary:"+(string)powered+","+(string)poweracs+","+(string)powertofull;
                
                llRegionSayTo(id, channel_acsi, chargesum_answer);
            }
            else if(acsi_msg == "ACS,charging:1")
            {
                llWhisper(0,"/me charging initiated.");
                
                integer poweracs = llFloor(power*100);
                if(poweracs>99)
                {
                    llRegionSayTo(id, channel_acsi, "ACS,stopcharge:");
                }
            }
            else if(acsi_msg == "ACS,charging:0")
            {
                llWhisper(0,"/me charging terminated.");
            }
            else if(llGetSubString(acsi_msg, 0, 17) == "ACS,chargeseconds:" || llGetSubString(acsi_msg, 0, 13) == "ACS,setcharge:")
            {
                float battery_add = (float)llGetSubString(acs_msg, 18, -1);
                power_rate = battery_add*1000;
                ischarging = TRUE;
                powermanager(power_rate, ischarging);
                integer chargeticks = llFloor(battery_level);
                string chargetick_answer = "ACS,chargeticks:"+(string)chargeticks;
                llRegionSayTo(id, channel_acsi, chargetick_answer);
            }
            else if(acsi_msg == "ACS,disconnect:")
            {
                llRegionSayTo(id, channel_acsi, "ACS,goodbye:");
                llWhisper(0, "/me automatically disconnects from "+name);
            }
        } */
        
        // NS BATTERY CHANNEL
        else if(channel==batchan1)
        {
            console_debug(message, channel);
            if(llGetSubString(message,0,4)=="spec ")
            {
                list batcap = llParseString2List(llGetSubString(message,5,-1), [" "], []);
                battery_capacity = llList2Float(batcap,0);
                battery_level = llList2Float(batcap,1);
            }
        }
        
        // NS DEVICES COMMUNICATION CHANNEL (weapons, icons, ...)
        else if(channel==55 && message=="reload" && id==llGetOwner())
        {
            float wcharge = 5.0;
            llRegionSayTo(id, channel_lights, "weapon charge "+(string)wcharge);
        }
        
        // TEST COMMAND CHANNEL FOR DEBUG
        else if(channel==2 && id==llGetOwner())
        {
            if(message == "help")
            {
                llOwnerSay("Commands:\n repeat <message>\n chstop\n chexit\n !release\n !capture\n rate <float>W <0/1>\n probe\n ping\n ident\n reset");   
            }
            else if(llGetSubString(message, 0, 6)=="repeat ")
            {
               llOwnerSay("Sending broadcast message...");
               llSleep(1.0);
               string message = llGetSubString(message, 7, -1);
               llSay(0, message); // owner
               llRegionSay(-205862283, "relay "+message); // Aetheria
               //llRegionSay(-998117989, "relay "+message); // cort4na
               llRegionSay(-500117989, "relay "+message); // cort4na
            }
            else if(message == "chstop")
            {
                llSay(channel_acsi, "ACS,stopcharge:"); 
            }
            else if(message == "chexit")
            {
                llSay(channel_acs, "ACS,goodbye:");       
            }
            else if(message == "!release")
            {
                llOwnerSay("Releasing chat...");
                llSleep(1.0);
                llOwnerSay("@redirchat:"+(string)channel_rlvhook+"=rem");
                llOwnerSay("@rediremote:"+(string)channel_rlvhook+"=rem");   
            }
            else if(message == "!capture")
            {
                llOwnerSay("Capturing chat...");
                llSleep(1.0);
                llOwnerSay("@redirchat:"+(string)channel_rlvhook+"=add");
                llOwnerSay("@rediremote:"+(string)channel_rlvhook+"=add");  
            }
            else if(llGetSubString(message, 0, 4)=="rate ")
            { 
                list command = llParseString2List(message, [" "], []);
                power_rate = llList2Float(command, 1);
                ischarging = llList2Integer(command, 2);
                powermanager(power_rate, ischarging);
                llOwnerSay("Set power rate to "+(string)llFloor(power_rate)+"W (charging="+(string)ischarging+")");
                llSleep(1.0);
            }
            else if(message == "ping")
            { 
                llRegionSay(channel_public, "ping "+(string)channel_ping);
            }
            else if(message == "ident")
            { 
                llRegionSay(channel_public, "identify "+(string)channel_ping);
            }
            else if(message == "reset")
            { 
                restart();
            }
            else if(llGetSubString(message, 0, 5) == "color ")
            {
                list rgb = llParseString2List(llGetSubString(message, 6, -1), [" "], []);
                color = <llList2Float(rgb, 0), llList2Float(rgb, 1), llList2Float(rgb, 2)>; // Color as vector
                color_msg = (string)String2Float(llList2String(rgb, 0))+" "+(string)String2Float(llList2String(rgb, 1))+" "+(string)String2Float(llList2String(rgb, 2)); // Color color as string
                set_lights(1.0); 
                send_color(llGetOwner()); // Send color on lightbus for all attached devices
                llRegionSayTo(llGetOwnerKey(id), 0, "Updating color."); // Tell operator that color has changed
            }
        }
        
        // ASN STARGATE TP
        else if(channel==-900000)
        {
            llOwnerSay("Stargate telemetry received.");
            llSleep(0.1);
            list target = llParseString2List(message, ["|"] ,[]);
            if(llList2String(target, 0) == "map")
            {
                key k = (key) llList2String(target, 1);
                if(k == llGetOwner())
                {
                    llOwnerSay("Jump command synchronized.");
                    llSleep(0.1);
                    simq = llRequestSimulatorData (llList2String (target, 2), DATA_SIM_POS);
                    localpos = (vector)llList2String(target, 3);
                }
            }
        }
        
        // RLV CHAT HOOK
        else if(channel==channel_rlvhook)
        {
            integer strlen = llStringLength(message);
            
            if(llGetSubString(message,0,1)=="s ")
            {
                power_rate = strlen * 3.0;
                llShout(0,llGetSubString(message,2,-1));    
            }
            else if(llGetSubString(message,0,1)=="w ")
            {
                 power_rate = strlen * 0.5;
                 llWhisper(0,llGetSubString(message,2,-1));    
            }
            else
            {
                 power_rate = strlen * 1.5;
                 llSay(0,message);   
            }

            ischarging = FALSE;
            powermanager(power_rate, ischarging);
            llPlaySound("437185ea-a940-9689-7e87-0737585fb1ee",1.0);      
        }
        
        // RLV RELAY STUFF
        else if(channel==channel_rlvrc)
        {
            list object_details = llGetObjectDetails(id,[OBJECT_CREATOR]); // check creators uuid
            key creator = llList2Key(object_details,0);
            
            if(creator==novum_creator) // NOVUM STARGATE TP
            {
                llOwnerSay("Stargate telemetry received.");
                llSleep(0.1);
                
                list full_cmd = llParseString2List(message, [","] ,[]);
                string cmd_name = llList2String(full_cmd,0);
                key target = llList2Key(full_cmd,1);
                string cmds = llList2String(full_cmd,2);
                list cmdz = llParseString2List(cmds, ["|"] ,[]);
                
                llOwnerSay("(debug:novum) "+cmds);
                
                if(llList2String(cmdz, 1) == "@tpto:")
                {
                    llOwnerSay("Jump command synchronized.");
                    llSleep(0.1);
                    
                    //simq = llRequestSimulatorData (llList2String (target, 2), DATA_SIM_POS);
                    //localpos = (vector)llList2String(target, 3);
                    
                    /* llOwnerSay("Destination coordinates locked. Engaging external FTL.");
                    llSleep(0.1);
                    
                    llOwnerSay(cmd_name+","+(string)target+","+(string)cmds);
                    
                    llSleep(2.0);
                    llOwnerSay("Passive teleport complete."); */
                }
            }
            else
            {
                llOwnerSay("Unauthorized RLV access by object "+llKey2Name(id)+" from owner secondlife:///app/agent/"+(string)llGetOwnerKey(id)+"/about (by creator: secondlife:///app/agent/"+(string)creator+"/about)");    
            }
        }
    }
    
    dataserver(key queryid, string data)
    {
        if (queryid == simq)
        {
            global_pos = (vector)data + localpos;
            string pos_str = (string)((integer)global_pos.x) + "/" + (string)((integer)global_pos.y) + "/" + (string)((integer)global_pos.z);
            llOwnerSay("Destination coordinates locked. Engaging external FTL.");
            llSleep(0.1);
            llOwnerSay("@tpto:" + pos_str + "=force");
            llSleep(2.0);
            llOwnerSay("Passive teleport complete.");
            //llTeleportAgentGlobalCoords(llGetOwner(), global_pos, localpos, ZERO_VECTOR);
        }
    }
    
    link_message(integer src, integer channel, string message, key id)
    {
        console_debug((string)channel+"|"+(string)message+"|"+(string)id, 0);
        if(channel==666)
        {
            float damagevalue=(float)message;
            key attacker=id;
            healthmanager(attacker, damagevalue, FALSE);
            if(debug_output==TRUE){if(damagevalue>1){llOwnerSay("[DEBUG] attacker="+llGetUsername(attacker)+"|damage="+(string)damagevalue);}}
        }
        if(channel==SCREEN_COLOR){ // 28
            /* list rgb = llParseString2List(llGetSubString(message, 6, -1), [" "], []);
            color = <llList2Float(rgb, 0), llList2Float(rgb, 1), llList2Float(rgb, 2)>; // Color as vector
            color_msg = (string)String2Float(llList2String(rgb, 0))+" "+(string)String2Float(llList2String(rgb, 1))+" "+(string)String2Float(llList2String(rgb, 2)); */
        }    
        if(channel==CHARGING){    
            if(message=="start"){ischarging=TRUE;}
            if(message=="stop"){ischarging=FALSE;}
            if(message=="query level"){llMessageLinked(LINK_SET,POWER_LEVEL,(string)battery_level,"");}
            if(message=="query capacity"){llMessageLinked(LINK_SET,POWER_CAPACITY,(string)battery_capacity,"");}
            if(message=="query rate"){llMessageLinked(LINK_SET,POWER_RATE,(string)power_rate,"");}
                
            if(llGetSubString(message,0,2)=="add"){
                //battery_level=battery_level+(float)llDeleteSubString(message,0,3);
                float add = (float)llDeleteSubString(message,3,-1);
                power_rate = add*1000;
                //ischarging = TRUE; // (not needed) check a few lines above 
            }
            
            powermanager(power_rate, ischarging);
        } 
        if(channel==INTERFERENCE){
            //llMessageLinked(LINK_SET,INTERFERENCE,"<int:type>,<float:duration>",""); 
            
            list interfere = llParseString2List(message, [","] ,[]);
            emi_type = llList2Integer(interfere, 0);
            emi_duration = llList2Float(interfere, 1);
        }
    }
    
    timer()
    {
        movemanager();
        radmanager(emi_type, emi_duration);
        //powermanager(power_rate, ischarging);
        chronometer();
    } 
}