dofile("noglobals.lua")

local qptest = "qptest.bin"
local eqptest = "qptest.bin2"
local dqptest = "qptest.bin3"

local b64test = "luasocket"
local eb64test = "b64test.bin"
local db64test = "b64test.bin2"

-- from Machado de Assis, "A M�o e a Rosa"
local mao = [[
    Cursavam estes dois mo�os a academia de S. Paulo, estando 
    Lu�s Alves no quarto ano e Est�v�o no terceiro. 
    Conheceram-se na academia, e ficaram amigos �ntimos, tanto
    quanto podiam s�-lo dois esp�ritos diferentes, ou talvez por 
    isso mesmo que o eram. Est�v�o, dotado de extrema
    sensibilidade, e n�o menor fraqueza de �nimo, afetuoso e
    bom, n�o daquela bondade varonil, que � apan�gio de uma alma
    forte, mas dessa outra bondade mole e de cera, que vai �
    merc� de todas as circunst�ncias, tinha, al�m de tudo isso, 
    o infort�nio de trazer ainda sobre o nariz os �culos 
    cor-de-rosa de suas virginais ilus�es. Lu�s Alves via bem
    com os olhos da cara. N�o era mau rapaz, mas tinha o seu
    gr�o de ego�smo, e se n�o era incapaz de afei��es, sabia
    reg�-las, moder�-las, e sobretudo gui�-las ao seu pr�prio
    interesse.  Entre estes dois homens travara-se amizade
    �ntima, nascida para um na simpatia, para outro no costume.
    Eram eles os naturais confidentes um do outro, com a
    diferen�a que Lu�s Alves dava menos do que recebia, e, ainda
    assim, nem tudo o que dava exprimia grande confian�a.
]]

local fail = function(s)
    s = s or "failed"
	assert(nil, s)
end

local readfile = function(name)
	local f = io.open(name, "r")
	if not f then return nil end
	local s = f:read("*a")
	f:close()
	return s
end

local function transform(input, output, filter)
    local fi, err = io.open(input, "rb")
    if not fi then fail(err) end
    local fo, err = io.open(output, "wb")
    if not fo then fail(err) end
    while 1 do 
        local chunk = fi:read(math.random(0, 256))
        fo:write(filter(chunk))
        if not chunk then break end
    end 
    fi:close()
    fo:close()
end

local function compare(input, output)
    local original = readfile(input)
    local recovered = readfile(output)
    if original ~= recovered then fail("recovering failed")
    else print("ok") end
end

local function encode_qptest(mode)
    local encode = socket.mime.encode("quoted-printable", mode)
    local split = socket.mime.wrap("quoted-printable")
    local chain = socket.mime.chain(encode, split)
    transform(qptest, eqptest, chain)
end

local function compare_qptest()
    compare(qptest, dqptest)
end

local function decode_qptest()
    local decode = socket.mime.decode("quoted-printable")
    transform(eqptest, dqptest, decode)
end

local function create_qptest()
    local f, err = io.open(qptest, "wb")
    if not f then fail(err) end
    -- try all characters
    for i = 0, 255 do
        f:write(string.char(i))
    end
    -- try all characters and different line sizes
    for i = 0, 255 do
        for j = 0, i do
            f:write(string.char(i))
        end
        f:write("\r\n")
    end
    -- test latin text
    f:write(mao)
    -- force soft line breaks and treatment of space/tab in end of line
    local tab
    f:write(string.gsub(mao, "(%s)", function(c)
        if tab then
            tab = nil
            return "\t"
        else
            tab = 1
            return " "
        end
    end))
    -- test crazy end of line conventions
    local eol = { "\r\n", "\r", "\n", "\n\r" }
    local which = 0
    f:write(string.gsub(mao, "(\n)", function(c)
        which = which + 1
        if which > 4 then which = 1 end
        return eol[which]
    end))
    for i = 1, 4 do
        for j = 1, 4 do
            f:write(eol[i])
            f:write(eol[j])
        end
    end
    -- try long spaced and tabbed lines
    f:write("\r\n")
    for i = 0, 255 do
        f:write(string.char(9))
    end
    f:write("\r\n")
    for i = 0, 255 do
        f:write(' ')
    end
    f:write("\r\n")
    for i = 0, 255 do
        f:write(string.char(9),' ')
    end
    f:write("\r\n")
    for i = 0, 255 do
        f:write(' ',string.char(32))
    end
    f:write("\r\n")
    
    f:close()
end

local function cleanup_qptest()
    os.remove(qptest)
    os.remove(eqptest)
    os.remove(dqptest)
end

local function encode_b64test()
    local e1 = socket.mime.encode("base64")
    local e2 = socket.mime.encode("base64")
    local e3 = socket.mime.encode("base64")
    local e4 = socket.mime.encode("base64")
    local sp4 = socket.mime.wrap("character")
    local sp3 = socket.mime.wrap("character", 59)
    local sp2 = socket.mime.wrap("character", 30)
    local sp1 = socket.mime.wrap("character", 27)
    local chain = socket.mime.chain(e1, sp1, e2, sp2, e3, sp3, e4, sp4)
    transform(b64test, eb64test, chain)
end

local function decode_b64test()
    local d1 = socket.mime.decode("base64")
    local d2 = socket.mime.decode("base64")
    local d3 = socket.mime.decode("base64")
    local d4 = socket.mime.decode("base64")
    local chain = socket.mime.chain(d1, d2, d3, d4)
    transform(eb64test, db64test, chain)
end

local function cleanup_b64test()
    os.remove(eb64test)
    os.remove(db64test)
end

local function compare_b64test()
    compare(b64test, db64test)
end

local function padcheck(original, encoded)
    local e = (socket.mime.b64(original))
    local d = (socket.mime.unb64(encoded))
    if e ~= encoded then fail("encoding failed") end
    if d ~= original then fail("decoding failed") end
end

local function chunkcheck(original, encoded)
    local len = string.len(original)
    for i = 0, len do
        local a = string.sub(original, 1, i)
        local b = string.sub(original, i+1)
        local e, r = socket.mime.b64(a, b)
        local f = (socket.mime.b64(r))
        if (e .. f ~= encoded) then fail(e .. f) end
    end
end

local function padding_b64test()
    padcheck("a", "YQ==")
    padcheck("ab", "YWI=")
    padcheck("abc", "YWJj")
    padcheck("abcd", "YWJjZA==")
    padcheck("abcde", "YWJjZGU=")
    padcheck("abcdef", "YWJjZGVm")
    padcheck("abcdefg", "YWJjZGVmZw==")
    padcheck("abcdefgh", "YWJjZGVmZ2g=")
    padcheck("abcdefghi", "YWJjZGVmZ2hp")
    padcheck("abcdefghij", "YWJjZGVmZ2hpag==")
    chunkcheck("abcdefgh", "YWJjZGVmZ2g=")
    chunkcheck("abcdefghi", "YWJjZGVmZ2hp")
    chunkcheck("abcdefghij", "YWJjZGVmZ2hpag==")
    print("ok")
end

local t = socket.time()

create_qptest()
encode_qptest()
decode_qptest()
compare_qptest()
encode_qptest("binary")
decode_qptest()
compare_qptest()
cleanup_qptest()

encode_b64test()
decode_b64test()
compare_b64test()
cleanup_b64test()
padding_b64test()

print(string.format("done in %.2fs", socket.time() - t))
