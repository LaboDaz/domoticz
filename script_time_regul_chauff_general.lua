--[[
D'après vil1driver et Nissa (easydomoticz.com)
Daz 2017 rev 19/09/2017
Placé dans /home/pi/domoticz/scripts/lua 

script_time_regul_chauff_general.lua

]]--

----------------------------------------------
------          Configuration          ------
----------------------------------------------

-- consignes de thermostats virtuels

local consigne_confort = 'thermostatConfo'             
local consigne_eco = 'thermostatEco'
local consigne_nuit = 'thermoNuit'
local consigne_ecomoins = 'thermostatEcoMoins'

--declaration variables

local debug = false                      -- true or false pour voir tous les messages debug dans le log
local hysteresis = 0.4                -- Valeur seuil pour éviter que le relais ne cesse de commuter dans les 2 sens

-- email + push

local mail = ''         -- pour réception alerte sonde muette (chauffage coupé)
-- TODO PARAM PUSH


local url = 'user:mdp@ip:port'         -- user:pass@ip:port de domoticz, pour la création des variables

----------------------------------------------
--       Fin de la partie configuration       --
----------------------------------------------


function timedifference(d)

   s = otherdevices_lastupdate[d]
   year = string.sub(s, 1, 4)
   month = string.sub(s, 6, 7)
   day = string.sub(s, 9, 10)
   hour = string.sub(s, 12, 13)
   minutes = string.sub(s, 15, 16)
   seconds = string.sub(s, 18, 19)
   t1 = os.time()
   t2 = os.time{year=year, month=month, day=day, hour=hour, min=minutes, sec=seconds}
   difference = os.difftime (t1, t2)
   return difference

end

--cumul_power = 0   -- initialisation de la puissance instantanee des radiateurs en fonctionnement


   -- Maj des variables en fonction de la valeur de la table 

   local sonde = 'sondeThermHygro'                  -- Nom de la sonde de température
   local presence =  'thermostatSwitch'        -- Interrupteur manuel indiquant la presence
   local switchDeshumid = 'deshumidSwitch' --Interrupteur manuel pour dire de déshumidifier
   local desactiverMomentanement = 'desactiverChauff30mnSwitch'
   local switchSdb='chauffSdbProgrammeSwitch'

   local calendrier = 'calendrierChauffageChambreSejour'
   local calendrierNuit = 'calendrierChauffageNuit'
   local calendrierSdb= 'calendrierChauffageSdB'

   local rad1 = 'radChambre'      -- Nom de l'interrupteur de chauffage
   local rad2 = 'radSejour'  
   local radSdb = 'radSdb'

   local deshumid1='deshumidSejour'
   local deshumid2='deshumidSdb'

   log = '***'
   log2 = '***'

   local heure = string.sub(os.date("%X"), 1, 5)   -- Recuperation de l'heure du systeme
   local lastSeen = string.sub(os.date("!%X", timedifference(sonde)), 1, 5)    -- Heure de la derniere releve de la sonde de temperature
   local lastSeenSwitchTempo=string.sub(os.date("!%X", timedifference(desactiverMomentanement)), 1, 5) 
   local lastSeenSdb=string.sub(os.date("!%X", timedifference(radSdb)), 1, 5)  -- il faut forcer l'extinction du radiateur Sdb (risque incendie) s'il reste allumé trop longtemps

   commandArray = {}
----------------------------------------------
------         Alerte mail              ------
--     si la sonde est muette depuis 30'    --
----------------------------------------------

   if (lastSeen >= '00:30' and lastSeen < '00:32') then

      commandArray['SendEmail']='Domoticz Alerte#Alerte sonde muette#'..mail

      	commandArray[rad1]='Off'  
	commandArray[radSdb]='Off' 
         commandArray[rad2]='Off' 
	commandArray[deshumid1]='Off'  
         commandArray[deshumid2]='Off'
      if (debug) then print('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Envoi mail probleme de sonde. Les radiateurs et deshumidificateurs ont été coupés.') end

   end

----------------------------------------------
------          Gestion consigne        ------
----------------------------------------------
   
-- on récupère la consigne humidité en %. Ici car besoin de cette instruction même si desactiverMomentanément == TRUE
	consigneHum=tonumber(otherdevices_svalues['consigneHumid'])
	temperature = tonumber(string.sub(otherdevices_svalues[sonde],1,4))
--temperature1, hygro1 = otherdevices_svalues[sond]:match("([^;]+),([^;]+)")
	hygro = tonumber(string.sub(otherdevices_svalues[sonde],6,7))

--ajout switch virtuel désactivé pendant 30mn

  if ((otherdevices[desactiverMomentanement] == 'On') and (lastSeenSwitchTempo < '00:30')) then
	if (debug) then print('Chauffage manuellement interrompu depuis moins de 30 min') end
	commandArray[rad1]='Off'  
         commandArray[rad2]='Off' 
	commandArray[radSdb]='Off' 
	if (debug) then print('Les 2 radiateurs + soufflant Sdb ont été éteints') end  
	else

   -- récupération de la valeur du thermostat

    if (otherdevices[presence] == 'On') then          -- si la presence est active 

		if (otherdevices[calendrierNuit] == 'On') then       -- ET calendrier nuit
			consigne=tonumber(otherdevices_svalues[consigne_nuit])
		else

      			if (otherdevices[calendrier] == 'On') then       -- calendrier jour
         		consigne = tonumber(otherdevices_svalues[consigne_confort])
		 	
			else
         		consigne = tonumber(otherdevices_svalues[consigne_eco])
			end

     		end
   else     -- presence = OFF
      consigne = tonumber(otherdevices_svalues[consigne_ecomoins])
	commandArray[deshumid1]='Off'  
         commandArray[deshumid2]='Off' 
   end   

     -- on récupère la température fournie par la sonde
if (debug) then
print( "TEMP SONDE:"..temperature)
print( "HYGRO SONDE:"..hygro)
print( "lAST SEEN:"..lastSeen)
print( "CONSIGNE TEMP:"..consigne)
print( "CONSIGNE HUMID:"..consigneHum)
print( "HYSTERESIS:"..hysteresis)
end

----------------------------------------------

------       Gestion du radiateur       ------

--- selon temperature relevee et consigne   --

----------------------------------------------


   if (temperature >= (consigne + hysteresis/2) or lastSeen > '00:10') then    -- Temperature superieure ou = a la consigne + hysteris (soit si 19,5° = 19,5) ou sonde muette (10 min sans réponse)

      if ((otherdevices[rad1] == 'On') or (otherdevices[rad2] == 'On')) then          -- on stoppe la chauffe si le radiateur 1 est sur On

         commandArray[rad1]='Off'  
         commandArray[rad2]='Off'   

         if (debug) then print('>>>temperature >= (consigne + hysteresis) or lastSeen et radiateurs à On. Donc on les met à Off. Ils resteront éteints jusqu a la prochaine phase de chauffe') end

      end
	
 	commandArray[rad1]='Off'  
        commandArray[rad2]='Off'   	  
	if (debug) then print('>>>temperature >= (consigne + hysteresis) or lastSeen et radiateurs à On. Donc on les met à Off. Ils resteront éteints jusqu a la prochaine phase de chauffe') end
      if (lastSeen > '00:10') then
		log2 = '***        Sonde muette '
	end

      log = '***                              Les radiateurs sont arrêtés'

      status = 0	  -- Pour eviter le delai de la Maj du device (variable utilisee dans le if du calcul de conso)                 

   else    -- la température est inférieure à la consigne - hysteresis/2 (soit si 19° = 18,8) et la sonde est OK

      if (temperature < (consigne-hysteresis/2)) then

         if ((otherdevices[rad1] == 'Off') or (otherdevices[rad2] == 'Off')) then   

            commandArray[rad1]='On'   -- on allume le radiateur 1
            commandArray[rad2]='On'

            log = '***                              Les radiateurs sont en marche'

            status = 1    

            if (debug) then print('>>>temperature <= (consigne - hysteresis et radiateur 1 à Off. Donc on le met à On') end

         else

            log = '***                              Les radiateurs sont déjà en marche, on les force à On car parfois il y a perte de signal'
	    commandArray[rad1]='On'   -- on allume le radiateur 1
            commandArray[rad2]='On'
            status = 1

         end

      else -- température de consigne non atteinte, on laisse chauffer

         --commandArray[rad1]='Off'
         --commandArray[rad2]='Off'
         --status = 0
         log = '***                              Température comprise dans la marge hysteresis, on ne change pas état radiateurs'   

      end

     end

   end

   
   -- logs
	if  ((otherdevices[desactiverMomentanement] == 'Off') or (lastSeenSwitchTempo >= '00:30')) then
   print('********************* Chauffage *********************')

   print('***                 Il fait '..temperature..'°C pour une consigne de '..consigne..'°C souhaités')

   print(log,log2)

   print('********************************************************************')
	else
  print('Chauffage momentanément interrompu pour une durée de 30 min')
end


if ((hygro>=consigneHum) and (otherdevices[presence] == 'On') and (otherdevices[switchDeshumid] =='On') and (lastSeen < '00:10'))  then
	print('********************* Humidité *********************')
	print('*** Humidité de '..hygro..'% : Déshumidificateurs enclenchés')
   	print('********************************************************************')
	commandArray[deshumid1]='On'
        commandArray[deshumid2]='On'
else
	print('********************* Humidité *********************')
	print('Humidité< '..consigneHum..'% ou présence off ou switchDeshumid off ou sonde ne répond plus. Déshumidificateurs éteints.')
   	print('********************************************************************')	
	commandArray[deshumid1]='Off'
        commandArray[deshumid2]='Off'
	
end

-- chauffage programmé de la Sdb
if (otherdevices[switchSdb] == 'Off') then
commandArray[radSdb]='Off'
end

if (otherdevices[switchSdb] == 'On') then

if (otherdevices[calendrierSdb] == 'On') then
    print('********************* Chauffage Sdb enclenché *********************')
     commandArray[radSdb]='On'
else
     print('********************* Chauffage Sdb éteint *********************')
     commandArray[radSdb]='Off'
end
else

print('********************* Chauffage Sdb éteint *********************')
	commandArray[radSdb]='Off'

end

-- fin de tableau

   return commandArray
