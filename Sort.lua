local ADDON_NAME, private = ...

private.SORT_FUNCTIONS = {
    NAME_ASC = function(a, b)
        return a["NAME"] < b["NAME"]
    end,
    FISH_ASC = function(a, b)
        return a["FISH"] < b["FISH"]
    end,
    AMOUNT_ASC = function(a, b)
        if (a["AMOUNT"] == b["AMOUNT"]) then
            return a["NAME"] < b["NAME"]
        else
            return a["AMOUNT"] < b["AMOUNT"]
        end
    end,
    STATUS_ASC = function(a, b)
        if (a["STATUS"] == b["STATUS"]) then
            return a["NAME"] < b["NAME"]
        else
            return a["STATUS"] < b["STATUS"]
        end
    end,
    NEED_ASC = function(a, b)
        return a["NEED"] < b["NEED"]
    end,
    NAME_DESC = function(a, b)
        return a["NAME"] > b["NAME"]
    end,
    FISH_DESC = function(a, b)
        return a["FISH"] > b["FISH"]
    end,
    AMOUNT_DESC = function(a, b)
        if (a["AMOUNT"] == b["AMOUNT"]) then
            return a["NAME"] < b["NAME"]
        else
            return a["AMOUNT"] > b["AMOUNT"]
        end
    end,
    STATUS_DESC = function(a, b)
        if (a["STATUS"] == b["STATUS"]) then
            return a["NAME"] < b["NAME"]
        else
            return a["STATUS"] > b["STATUS"]
        end
    end,
    NEED_DESC = function(a, b)
        return a["NEED"] > b["NEED"]
    end
}
