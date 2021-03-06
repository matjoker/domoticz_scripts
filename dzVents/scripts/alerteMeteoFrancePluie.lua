--[[
alerteMeteoFrancePluie.lua
author/auteur = papoo
update/mise à jour = 11/05/2019
création = 09/03/2019
https://pon.fr/dzvents-alerte-previsions-de-pluie-prochaines-60-minutes
https://github.com/papo-o/domoticz_scripts/blob/master/dzVents/scripts/alerteMeteoFrancePluie.lua
https://easydomoticz.com/forum/viewtopic.php?f=17&t=5492

Principe : récupérer via l'API non documentée de météo France 
les informations de précipitation de votre commune sur un device alert et/ou text
la carte des départements couverts par ce service (ils ne le sont pas tous)
http://www.meteofrance.com/previsions-meteo-france/previsions-pluie

--]]
--------------------------------------------
------------ Variables à éditer ------------
--------------------------------------------
local CityCode      = 870850-- Le code de votre ville est l'ID retourné par cette URL : http://www.meteofrance.com/mf3-rpc-portlet/rest/lieu/facet/pluie/search/nom_de_votre_ville
local alert_device  = "Alerte Pluie"
local text_alert    = "Info Du Jour"

--------------------------------------------
----------- Fin variables à éditer ---------
--------------------------------------------
local scriptName        = 'météo France alerte pluie'
local scriptVersion     = '3.03'
local response = "meteoFrance_response"
return {
    on =        {       timer           =   { "every 5 minutes" },
                        httpResponses   =   {  response } },

    logging =   {   -- level    =   domoticz.LOG_DEBUG,
                    -- level    =   domoticz.LOG_INFO,             -- Seulement un niveau peut être actif; commenter les autres
                    -- level    =   domoticz.LOG_ERROR,            -- Only one level can be active; comment others
                    -- level    =   domoticz.LOG_MODULE_EXEC_INFO,
                    marker  =   scriptName..' v'..scriptVersion },

    execute = function(dz, item)

        local devAlert      = dz.devices(alert_device)

        local function logWrite(str,level)
            dz.log(tostring(str),level or dz.LOG_DEBUG)
        end
        local function seuilAlerte(level)
            if level == 0 or level == nil then return domoticz.ALERTLEVEL_GREY end
            if level == 1 then return dz.ALERTLEVEL_GREEN end
            if level == 2 then return dz.ALERTLEVEL_YELLOW end
            if level == 3 then return dz.ALERTLEVEL_ORANGE end
            if level == 4 then return dz.ALERTLEVEL_RED end
        end
        local function highLevel(mn, level, lastLevel, commentaire)
            if lastLevel == nil or level > lastLevel then
                text = commentaire
                lastMn = mn
                return mn, level, text
            else
                return lastMn, lastLevel, text
            end
        end

            local function ReverseTable(t)
                local reversedTable = {}
                local itemCount = #t
                for k, v in ipairs(t) do
                    reversedTable[itemCount + 1 - k] = v
                end
                return reversedTable
            end

        if item.isHTTPResponse then
            local prevision1heure        = item.json.niveauPluieText[1]
            logWrite("Prévisions de pluie pour la prochaine heure    : " .. prevision1heure    )
            logWrite("---------------------------------------------------")

            local dataCadran            = {}
            dataCadran = item.json.dataCadran
            local InfoNiveauPluieText   = {}
            local InfoNiveauPluie       = {}
            local InfoColor             = {}
            local lastLevel             = nil
            local level                 = nil
            local text                  = nil
            local mn                    = nil
            local lastMn                = nil
            local j                     = 60
            if dataCadran ~= nil then
            dataCadran = ReverseTable(dataCadran)
                for i, Result in ipairs( dataCadran ) do
                    InfoNiveauPluieText[i] = Result.niveauPluieText
                    InfoNiveauPluie[i] = Result.niveauPluie
                    InfoColor[i] = Result.color
                    logWrite("--- --- --- prévision à ".. j .. "  mn : "..  InfoNiveauPluieText[i].. " Niveau : "..  InfoNiveauPluie[i] .. " couleur :" ..  InfoColor[i])
                    lastMn, lastLevel, text = highLevel(j, InfoNiveauPluie[i], lastLevel, InfoNiveauPluieText[i])
                j = j-5
                end
                if text_alert ~= nil then
                dz.devices(text_alert).updateText(prevision1heure)
                else 
                text = text .. ' dans les ' .. lastMn .. ' prochaines minutes'
                end
                if alert_device ~= nil then
                    if devAlert.color ~= lastLevel or devAlert.lastUpdate.minutesAgo > 1440 then
                        logWrite('le device '.. devAlert.name ..' est à '.. tostring(devAlert.color) ..' et son texte est ' .. tostring(devAlert.text))
                        devAlert.updateAlertSensor(seuilAlerte(lastLevel), text)
                    elseif devAlert.text ~= text then
                        logWrite('le device '.. devAlert.name ..' est à '.. tostring(devAlert.color) ..' et son texte est ' .. tostring(devAlert.text))
                        devAlert.updateAlertSensor(seuilAlerte(lastLevel), text)
                    end
                end
                logWrite('level est à '.. tostring(level))
                logWrite('lastLevel est à '.. tostring(lastLevel))
                logWrite('contenu de text : '.. tostring(text))
                logWrite('lastMn est à '.. tostring(lastMn))

            end

        else

            local url = "http://www.meteofrance.com/mf3-rpc-portlet/rest/pluie/"..CityCode..".json"

            dz.openURL({
                  url = url,
                        method = "GET",
                        callback = response})
        end
    end
}
