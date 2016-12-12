c = document.getElementById('draw')
ctx = c.getContext('2d')

delta = 0
now = 0
before = Date.now()
elapsed = 0

loading = 0

DEBUG = false

# c.width = window.innerWidth
# c.height = window.innerHeight

c.width = 800
c.height = 600

keysDown = {}
keysPressed = {}

window.addEventListener("keydown", (e) ->
    keysDown[e.keyCode] = true
    keysPressed[e.keyCode] = true
, false)

window.addEventListener("keyup", (e) ->
    delete keysDown[e.keyCode]
, false)


setDelta = ->
    now = Date.now()
    delta = (now - before) / 1000
    before = now

if not DEBUG
    console.log = () ->
        null

player =
    x: 0
    y: 0
    speed: 4
    color: '#ffffff'
    rotation: 0
    money: 750
    energy: 100
    hunger: 0
    sanity: 100
    state:
        name: 'standing'

room =
    width: 6
    height: 8


images = {}

items = [
    {
        name: 'lamp',
        image: 'lamp',
        price: 20,
        width: 1,
        height: 1,
        actions: [{
            name: 'look at light'
            f: ->
                if Math.random() < 0.5
                    player.sanity = clamp(player.sanity + (Math.random() * 2), 0, 100)
                    makePopup('+sanity', 'green')
                else
                    player.sanity = clamp(player.sanity - (Math.random() * 2), 0, 100)
                    makePopup('-sanity', 'red')
        }]
        requirements: []
    },
    {
        name: 'computer',
        image: 'computer',
        price: 500,
        width: 1,
        height: 1,
        actions: [{
            name: 'work'
            f: ->
                if player.energy <= 20
                    makePopup('you\'re too tired to work', 'white')
                    return

                player.money += 50
                makePopup('+$50', 'green')
                player.energy -= 20
                makePopup('-energy', 'red', 0.5)
                player.sanity -= (Math.random() * 14 + 6)
                makePopup('-sanity', 'red', 1.0)
            }, {
            name: 'play'
            f: ->
                if player.energy <= 10
                    makePopup('you\'re too tired to play', 'white')
                    return

                player.energy -= 10
                makePopup('-energy', 'red')
                player.sanity = clamp(player.sanity + Math.random() * 5, 0, 100)
                makePopup('+sanity', 'green', 0.5)
            },
        ]
        requirements: ['lamp']
    },
    {
        name: 'bed',
        image: 'bed',
        price: 400,
        width: 1,
        height: 2,
        actions: [{
            name: 'sleep',
            f: ->
                fadeOut(->
                    fadeIn()
                )
                player.energy = clamp(player.energy + Math.random() * 50 + 30, 0, 100)
                player.hunger = clamp(player.hunger + Math.random() * 30, 0, 100)
                makePopup('+energy', 'green', 2.0)
                makePopup('+hunger', 'red', 2.5)
            },
        ]
        requirements: ['lamp']
    },
    {
        name: 'fridge',
        image: 'fridge',
        price: 800,
        width: 1,
        height: 1,
        actions: [{
            name: 'eat',
            f: ->
                if player.money <= 20
                    makePopup('you can\'t afford that', 'white')
                    return

                player.hunger = clamp(player.hunger - (Math.random() * 20 + 10), 0, 100)
                makePopup('-hunger', 'green')
            },
        ]
        requirements: ['lamp']
    },
]

itemsAvailable = []

itemPlaced = null

itemsBought = []

activeItem = null

buyMenu = false

ogre = false

fade = {
    state: 'none'
}

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

fadeOut = (cb) ->
    if fade.state == 'none'
        fade.state = 'out'
        fade.step = 0.0
        fade.cb = cb

fadeIn = (cb) ->
    if fade.state == 'none'
        fade.state = 'in'
        fade.step = 1.0
        fade.cb = cb

tick = ->
    setDelta()

    elapsed += delta

    update(delta)
    draw(delta)

    keysPressed = {}

    if not ogre

        window.requestAnimationFrame(tick)

tileFree = (x, y) ->
    if x < 0 or x >= room.width or y < 0 or y >= room.height
        return false

    if x == player.x and y == player.y
        return false

    for item in itemsBought
        if x >= item.x and x < item.x + item.item.width and
           y >= item.y and y < item.y + item.item.height

            return false

    return true

itemAvailable = (item) ->
    if item.price > player.money
        return false

    requiredMissing = item.requirements.length
    for r in item.requirements
        for item in itemsBought
            if item.item.name == r
                requiredMissing -= 1
                break

    return requiredMissing == 0

popups = []

makePopup = (text, color, delay=0) ->
    if color == 'green'
        color = '#408358'
    else if color == 'red'
        color = '#8c291b'

    popups.push
        text:     text
        x:        player.x * 32 + 16,
        y:        player.y * 32,
        color:    color,
        delay:    delay,
        speed:    20,
        duration: 1.5


getItemAt = (x, y) ->
    for item in itemsBought
        if x >= item.x and x < item.x + item.item.width and
           y >= item.y and y < item.y + item.item.height

            return item


update = (delta) ->
    console.log keysDown

    if fade.state == 'none'
        if buyMenu
            if keysPressed[66]
                buyMenu =  false
            else
                itemsAvailable = (item for item in items when itemAvailable(item))
                for i in [0..3]
                    if keysPressed[49 + i] and itemsAvailable[i]
                        itemPlaced =
                            x:    0,
                            y:    0,
                            item: itemsAvailable[i],


            if itemPlaced
                if keysPressed[68]
                    itemPlaced.x += 1
                if keysPressed[65]
                    itemPlaced.x -= 1
                if keysPressed[83]
                    itemPlaced.y += 1
                if keysPressed[87]
                    itemPlaced.y -= 1
                if keysPressed[32]
                    placeValid = true

                    for x in [0..itemPlaced.item.width - 1]
                        for y in [0..itemPlaced.item.height - 1]
                            if not tileFree(itemPlaced.x + x, itemPlaced.y + y)
                                placeValid = false

                    if placeValid
                        itemsBought.push(itemPlaced)
                        player.money -= itemPlaced.item.price
                        makePopup('-$' + itemPlaced.item.price, 'red')
                        itemPlaced = null
                        buyMenu = false

        else
            if keysPressed[66]
                buyMenu =  true

            if player.state.name == 'standing'
                if keysDown[68]
                    player.rotation = 0
                    if tileFree(player.x + 1, player.y)
                        player.state =
                            name: 'moving'
                            direction: 'right'
                if keysDown[65]
                    player.rotation = 180
                    if tileFree(player.x - 1, player.y)
                        player.state =
                            name: 'moving'
                            direction: 'left'
                if keysDown[83]
                    player.rotation = 90
                    if tileFree(player.x, player.y + 1)
                        player.state =
                            name: 'moving'
                            direction: 'down'
                if keysDown[87]
                    player.rotation = -90
                    if tileFree(player.x, player.y - 1)
                        player.state =
                            name: 'moving'
                            direction: 'up'
                if keysPressed[72] and activeItem and activeItem.item.actions[0]
                    activeItem.item.actions[0].f()
                if keysPressed[74] and activeItem and activeItem.item.actions[1]
                    activeItem.item.actions[1].f()
                if keysPressed[75] and activeItem and activeItem.item.actions[2]
                    activeItem.item.actions[2].f()
                if keysPressed[76] and activeItem and activeItem.item.actions[3]
                    activeItem.item.actions[3].f()


    if player.state.name == 'moving'
        if player.state.direction == 'right'
            if !player.state.target
                player.state.target = player.x + 1

            player.x += delta * player.speed
            if player.x >= player.state.target
                player.x = Math.round(player.state.target)
                player.state =
                    name: 'standing'
        if player.state.direction == 'left'
            if !player.state.target
                player.state.target = player.x - 1

            player.x -= delta * player.speed
            if player.x <= player.state.target
                player.x = Math.round(player.state.target)
                player.state =
                    name: 'standing'
        if player.state.direction == 'up'
            if !player.state.target
                player.state.target = player.y - 1

            player.y -= delta * player.speed
            if player.y <= player.state.target
                player.y = Math.round(player.state.target)
                player.state =
                    name: 'standing'
        if player.state.direction == 'down'
            if !player.state.target
                player.state.target = player.y + 1

            player.y += delta * player.speed
            if player.y >= player.state.target
                player.y = Math.round(player.state.target)
                player.state =
                    name: 'standing'

    for popup in popups
        popup.delay -= delta
        if popup.delay <= 0
            popup.y -= delta * popup.speed
            popup.duration -= delta
            if popup.duration <= 0
                popup.delete = true

    for popup, i in popups
        if popup.delete
            popups.splice(i, 1)
            break

    if Math.random() < 0.001
        player.sanity -= Math.random() * 6
        if player.hunger >= 80
            player.sanity -= Math.random() * 8
        if player.energy <= 10
            player.sanity -= Math.random() * 8
        makePopup('-sanity', 'red')

    if Math.random() < 0.001
        player.energy = clamp(player.energy - Math.random() * 6, 0, 100)
        if player.hunger >= 80
            player.energy = clamp(player.energy - Math.random() * 8, 0, 100)
        makePopup('-energy', 'red')

    if Math.random() < 0.001
        player.hunger = clamp(player.hunger + Math.random() * 6, 0, 100)
        makePopup('+hunger', 'red')

    frontTile =
        x: player.x
        y: player.y

    if player.rotation == 0
        frontTile.x += 1
    else if player.rotation == 90
        frontTile.y += 1
    else if player.rotation == 180
        frontTile.x -= 1
    else if player.rotation == -90
        frontTile.y -= 1


    activeItem = getItemAt(frontTile.x, frontTile.y)

    if player.sanity <= 0
        fadeOut(->
            ogre = true)

    if fade.state == 'out'
        fade.step += delta
        if fade.step >= 1.0
            fade.state = 'none'
            if fade.cb
                fade.cb()

    if fade.state == 'in'
        fade.step -= delta
        if fade.step <= 0.0
            fade.state = 'none'
            if fade.cb
                fade.cb()


draw = (delta) ->
    ctx.clearRect(0, 0, c.width, c.height)
    ctx.save()
    ctx.translate(32 * 10, 32 * 2)

    for x in [0..room.width - 1]
        drawRotatedImage(images['wall'], x * 32 + 16, -32 + 16, 0)

    drawRotatedImage(images['wall_corner'], -32 + 16, -32 + 16, 0)

    for y in [0..room.height - 1]
        drawRotatedImage(images['wall'], room.width * 32 + 16, y * 32 + 16, 90)

    drawRotatedImage(images['wall_corner'], room.width * 32 + 16, -32 + 16, 90)

    for x in [0..room.width - 1]
        drawRotatedImage(images['wall'], x * 32 + 16, room.height * 32 + 16, 180)

    drawRotatedImage(images['wall_corner'], room.width * 32 + 16, room.height * 32 + 16, 180)

    for y in [0..room.height - 1]
        drawRotatedImage(images['wall'], -32 + 16, y * 32 + 16, 270)

    drawRotatedImage(images['wall_corner'], -32 + 16, room.height * 32 + 16, 270)

    for x in [0..room.width - 1]
        for y in [0..room.height - 1]
            ctx.drawImage(images['floor'], x * 32, y * 32)

    drawRotatedImage(images['player'], player.x * 32 + 16, player.y * 32 + 16, player.rotation)

    for item in itemsBought
        ctx.drawImage(images[item.item.image], item.x * 32, item.y * 32)


    if DEBUG
        frontTile =
            x: player.x
            y: player.y

        if player.rotation == 0
            frontTile.x += 1
        else if player.rotation == 90
            frontTile.y += 1
        else if player.rotation == 180
            frontTile.x -= 1
        else if player.rotation == -90
            frontTile.y -= 1

        ctx.fillStyle = 'rgba(0, 200, 0, 0.5)'
        ctx.fillRect(frontTile.x * 32, frontTile.y * 32, 32, 32)


    if itemPlaced

        tintedName = itemPlaced.item.image + '-tinted'
        if not images[tintedName]

            fg = images[itemPlaced.item.image]

            buffer = document.createElement('canvas')
            buffer.width = fg.width
            buffer.height = fg.height
            bx = buffer.getContext('2d')

            bx.fillStyle = '#FF0000'
            bx.fillRect(0, 0, buffer.width, buffer.height)

            bx.globalCompositeOperation = "destination-atop"
            bx.drawImage(fg, 0, 0)

            images[tintedName] = buffer

        placeValid = true

        for x in [0..itemPlaced.item.width - 1]
            for y in [0..itemPlaced.item.height - 1]
                if not tileFree(itemPlaced.x + x, itemPlaced.y + y)
                    placeValid = false

        img = if placeValid then itemPlaced.item.image else tintedName

        ctx.drawImage(images[img], itemPlaced.x * 32, itemPlaced.y * 32)


    for popup in popups
        if popup.delay <= 0
            ctx.font = '14px Visitor'
            ctx.textAlign = 'center'
            ctx.fillStyle = popup.color
            ctx.fillText(popup.text, popup.x, popup.y)

    ctx.restore()

    if buyMenu
        ctx.fillStyle = '#222222'
        ctx.fillRect(0, 400, 800, 600)
        ctx.textAlign = 'center'
        ctx.fillStyle = '#ffffff'

        for item, i in itemsAvailable
            ctx.fillText('[' + (i + 1) + ']', 160 * (i + 1), 430)
            ctx.drawImage(images[item.image], 160 * (i + 1) - 16, 460)
            ctx.fillText(item.name, 160 * (i + 1), 550)
            ctx.fillText('$' + item.price, 160 * (i + 1), 566)

    ctx.font = '14px Visitor'
    ctx.textAlign = 'right'
    ctx.fillStyle = '#ffffff'
    ctx.fillText('energy', 50, 20)
    ctx.fillText('hunger', 50, 32)
    ctx.fillText('sanity', 50, 44)

    ctx.fillText('$' + player.money, 700, 44)

    ctx.fillRect(54, 14, player.energy, 6)
    ctx.fillRect(54, 26, player.hunger, 6)
    ctx.fillRect(54, 38, player.sanity, 6)

    if DEBUG
        ctx.fillText(Math.round(player.energy), 180, 20)
        ctx.fillText(Math.round(player.hunger), 180, 32)
        ctx.fillText(Math.round(player.sanity), 180, 44)


    ctx.textAlign = 'left'
    if itemPlaced
        ctx.fillText('[space] place', 340, 344)
    else if buyMenu
        ctx.fillText('[B] close', 340, 344)
    else
        ctx.fillText('[B] buy', 340, 344)

    buttons = ['H', 'J', 'K', 'L']
    if activeItem
       for action, i in activeItem.item.actions
           ctx.fillText('[' + buttons[i] + '] ' + action.name, 340, 360 + i * 16)

    ctx.textAlign = 'right'

    if fade.state != 'none'
        ctx.fillStyle = 'rgba(0, 0, 0, ' + fade.step + ')'
        ctx.fillRect(0, 0, 800, 600)

    if ogre
        ctx.fillStyle = '#000000'
        ctx.fillRect(0, 0, 800, 600)

        ctx.font = '180px Visitor'
        ctx.textAlign = 'center'
        ctx.textBaseline = 'middle'
        ctx.fillStyle = '#ffffff'
        ctx.fillText('THE END', 400, 300)

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

for img in ['floor', 'lamp', 'computer', 'bed', 'fridge', 'player', 'wall', 'wall_corner']
    loadImage(img)

load = ->
    if loading
        console.log(loading)
        window.requestAnimationFrame(load)
    else
        console.log('All loaded!')
        window.requestAnimationFrame(tick)

load()
