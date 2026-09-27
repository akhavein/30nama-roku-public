' Adapted from the MIT-licensed Paramount/Nayuki QRMode component to a pure value object.
function EasyQrMode(mode as String) as Object
    modes = {NUMERIC:{modeBits:1,numBitsCharCount:[10,12,14]},ALPHANUMERIC:{modeBits:2,numBitsCharCount:[9,11,13]},BYTE:{modeBits:4,numBitsCharCount:[8,16,16]},KANJI:{modeBits:8,numBitsCharCount:[8,10,12]},ECI:{modeBits:7,numBitsCharCount:[0,0,0]}}
    value = modes[mode]
    value.numCharCountBits = function(version as Integer) as Integer
        return m.numBitsCharCount[Int((version + 7) / 17)]
    end function
    return value
end function
