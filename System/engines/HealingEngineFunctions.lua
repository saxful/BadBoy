-- here we want to define functions to use with the healing profiles

-- find best tank to put our lb/beacon/earth shield on
function getFocusedTank()
    local tanks = getTanksTable()
    -- if we are targetting a mob and its targetting a tank we want to define which tank it is.
    if #tanks > 0 and UnitExists("target") and UnitIsVisible("target") and UnitExists("targettarget")
      and UnitIsVisible("targettarget") then
        local targetTargetGUID = UnitGUID("targettarget")
        for i = 1,#tanks do
            if tanks[i].guid == targetTargetGUID then
                oldTank = tanks[i]
                return tanks[i]
            end
        end
    elseif #tanks > 0 then
        -- otherwise we want to see which tank is beign targetted by its mob and whos threat is highest
        for i = 1,#tanks do
            print(UnitGUID(tanks[i].target)..""..tanks[i].guid)
            if UnitGUID(tanks[i].target) == tanks[i].guid then
                -- mob is on this unit
                oldTank = tanks[i]
                return tanks[i]
            end
        end
    else
        print(":( no tanks")
    end
end

-- find tanks
function getTanksTable()
    local tanksTable = {}
    for i = 1, #nNova do
        if nNova[i].role == "TANK" then
            tinsert(tanksTable, nNova[i])
        end
    end
    return tanksTable
end

-- we want to define an iteration that will compare allies to heal in range of enemies or allies
function castWiseAoEHeal(unitTable,spell,radius,health,minCount,maxCount,facingCheck,movementCheck)
    if movementCheck ~= true or not isMoving("player") then
        local bestCandidate = nil
        -- find best candidate with list of units
        for i = 1, #unitTable do
            -- added a visible check as its not in healing engine.
            if UnitIsVisible(unitTable[i].unit) and not (facingCheck ~= true and not getFacing("player",unitTable[i].unit)) then
                local candidate = getUnitsToHealAround(unitTable[i].unit,radius,health,maxCount,facingCheck)
                if bestCandidate == nil or bestCandidate[0].coef > candidate[0].coef then
                    bestCandidate = candidate
                end
            end
        end
        -- if we meet count minimum then we cast
        if bestCandidate ~= nil and #bestCandidate >= minCount then
            -- here we would like instead to cast on unit
            if castSpell(bestCandidate[0].unit,spell,facingCheck,movementCheck) then
                return true
            end
        end
    end
    return false
end


-- function to define range between players in tables.
function getNovaDistance(Unit1,Unit2)
    -- if we are comparing same unit return 0
    if Unit1.guid == Unit2.guid then
        return 0
    -- elseif unit 2 is valid (we have unit one valid check up before entering here)
    elseif Unit2 and Unit2.x ~= 0 then
        local X1,Y1,Z1 = Unit1.x,Unit1.y,Unit2.z
        local X2,Y2,Z2 = Unit2.x,Unit2.y,Unit2.z
        -- return distance between two users
        return math.sqrt(((X2-X1)^2)+((Y2-Y1)^2)+((Z2-Z1)^2))
    else
        return 1000
    end
end


-- now that we have our units in nNova with their positions, we can compare them to our enemies
-- we will send them as object args to our distance functions... since both engines have x and y, we will be able to mix them up
function getUnitsToHealAround(UnitID,radius,health,count)
    -- if we provide an unitID, we get this units location once
    local X1,Y1,Z1 = 0,0,0
    -- if an unit of type string is passed we consider it as a UnitID
    if type(UnitID) == "string" then
        X1,Y1,Z1 = ObjectPosition(UnitID)
    -- if we provide it a table, take that object position(accepts enemiesTable[i] or nNova[i])
    elseif UnitID and UnitID.x ~= 0 then
        X1,Y1,Z1 = UnitID.x,UnitID.y,UnitID.z
    end
    local unit = {x = X1,y = Y1,z = Z1,guid = UnitGUID(UnitID),name = UnitName(UnitID)}
    -- once we get our unit location we call our getdistance
    local lowHealthCandidates = {}
    for i = 1, #nNova do
        local thisUnit = nNova[i]
        -- if in given radius
        if thisUnit.hp <= health and getNovaDistance(unit,thisUnit) < radius then
            -- if its first item in table, insert
            if #lowHealthCandidates == 0 then
                tinsert(lowHealthCandidates, 1, {hp = thisUnit.hp,x = thisUnit.x,y = thisUnit.y,z = thisUnit.z,name = thisUnit.name,guid = thisUnit.guid})
            -- else compare and place our item at the right position in our table
            else
                -- scan from last to first and if higher just break out
                local lowHealthUnitsCount = #lowHealthCandidates
                local placedInTable = false
                local bestPosition = 0
                if lowHealthUnitsCount > 0 then
                    for j = lowHealthUnitsCount,1,-1 do
                        if thisUnit.hp < lowHealthCandidates[j].hp then
                            bestPosition = j
                        else
                            break
                        end
                    end
                end
                if bestPosition ~= 0 then
                    tinsert(lowHealthCandidates, bestPosition, {hp = thisUnit.hp,x = thisUnit.x,y = thisUnit.y,z = thisUnit.z,name = thisUnit.name,guid = thisUnit.guid})
                elseif lowHealthUnitsCount < count then
                    tinsert(lowHealthCandidates, lowHealthUnitsCount+1, {hp = thisUnit.hp,x = thisUnit.x,y = thisUnit.y,z = thisUnit.z,name = thisUnit.name,guid = thisUnit.guid})
                end
                if #lowHealthCandidates > count then
                    tremove(lowHealthCandidates[lowHealthUnitsCount])
                end
            end
        end
    end
    lowHealthCandidates[0] = { unit = UnitID, coef = getLowHealthCoeficient(lowHealthCandidates) }
    return lowHealthCandidates
end

-- returns coefficient of low health units around another unit
function getLowHealthCoeficient(lowHealthCandidates)
    local tableCoef = 0
    local lowHealthCount = #lowHealthCandidates
    -- if critical status, add it more coef
    for i = 1, lowHealthCount do
        local candidate = lowHealthCandidates[i]
        if candidate.hp < 30 then
            tableCoef = tableCoef + 1.5*(100-candidate.hp)
        else
            tableCoef = tableCoef + (100-candidate.hp)
        end
    end
    return tableCoef
end

-- old design with so many objectmanager queries it was wrong.
-- if getAllies("player",40) > 5 then
function getAllies(Unit,Radius)
    local alliesTable = {}
    for i=1,#nNova do
        if not UnitIsDeadOrGhost(nNova[i].unit) then
            if getDistance(Unit,nNova[i].unit) <= Radius then
                tinsert(alliesTable,nNova[i].unit)
            end
        end
    end
    return alliesTable
end

-- if getAlliesInLocation("player",X,Y,Z) > 5 then
function getAlliesInLocation(myX,myY,myZ,Radius)
    local alliesTable = {}
    for i=1,#nNova do
        if not UnitIsDeadOrGhost(nNova[i].unit) then
            if getDistanceToObject(nNova[i].unit,myX,myY,myZ) <= Radius then
                tinsert(alliesTable,nNova[i].unit)
            end
        end
    end
    return alliesTable
end

--We check if unit has a badly debuff thats need a personal CD to survive or reduce damage
--Todo check for more details for example how much damage are we going to take and whats the best spell to use.
--For example we can check if we are going to die or not.
function isBadlyDeBuffed(Unit)
    if Unit == nil then
        return false
    end
    
    for i=1,#novaEngineTables.BadlyDeBuffed do
        if UnitDebuffID(Unit,novaEngineTables.BadlyDeBuffed[i])~=nil then
            return true
        end
    end
    return false
end