c = document.getElementById('draw')
ctx = c.getContext('2d')

delta = 0
now = 0
before = Date.now()
elapsed = 0

loading = 0

# c.width = window.innerWidth
# c.height = window.innerHeight

c.width = 800
c.height = 600

keysDown = {}

window.addEventListener("keydown", (e) ->
    keysDown[e.keyCode] = true
, false)

window.addEventListener("keyup", (e) ->
    delete keysDown[e.keyCode]
, false)


setDelta = ->
    now = Date.now()
    delta = (now - before) / 1000
    before = now

player =
    x: 0
    y: 0
    speed: 70
    color: '#ffffff'

room =
    width: 5
    height: 5


images = {}


ogre = false

clamp = (v, min, max) ->
    if v < min then min else if v > max then max else v

collides = (a, b, as, bs) ->
    a.x + as > b.x and a.x < b.x + bs and a.y + as > b.y and a.y < b.y + bs

loadImage = (name) ->
    img = new Image()
    console.log 'loading'
    loading += 1
    img.onload = ->
        console.log 'loaded'
        images[name] = img
        loading -= 1

    img.src = 'img/' + name + '.png'

TO_RADIANS = Math.PI/180

drawRotatedImage = (image, x, y, angle) ->
    ctx.save()
    ctx.translate(x, y)
    ctx.rotate(angle * TO_RADIANS)
    ctx.drawImage(image, -(image.width/2), -(image.height/2))
    ctx.restore()


tick = ->
    setDelta()

    elapsed += delta

    update(delta)
    draw(delta)

    if not ogre

        window.requestAnimationFrame(update)


update = (delta) ->


draw = (delta) ->
    ctx.clearRect(0, 0, c.width, c.height)

    for x in [0..room.width]
        for y in [0..room.height]
            ctx.drawImage(images['floor'], x * 32, y * 32)

    drawRotatedImage(images['floor'], 200, 200, 45)

    ctx.fillStyle = '#ff00ff'
    ctx.fillRect(0, 0, 32, 32)

do ->
    w = window
    for vendor in ['ms', 'moz', 'webkit', 'o']
        break if w.requestAnimationFrame
        w.requestAnimationFrame = w["#{vendor}RequestAnimationFrame"]

    if not w.requestAnimationFrame
        targetTime = 0
        w.requestAnimationFrame = (callback) ->
            targetTime = Math.max targetTime + 16, currentTime = +new Date
            w.setTimeout (-> callback +new Date), targetTime - currentTime


loadImage('floor')

load = ->
    if loading
        console.log(loading)
        window.requestAnimationFrame(load)
    else
        console.log('All loaded!')
        window.requestAnimationFrame(tick)

load()
