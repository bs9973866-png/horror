extends Node3D

var player: CharacterBody3D
var camera: Camera3D
var flashlight: SpotLight3D
var monster: Node3D
var stamina := 100.0
var fragments := 0
var ended := false
var message: Label
var hud: Label
var look_id := -1
var last_pos := Vector2.ZERO
var sprinting := false
var move_vec := Vector2.ZERO
var collectibles: Array[Area3D] = []

func _ready() -> void:
    randomize()
    _world()
    _player()
    _ui()
    _say("FIND THREE SIGNAL FRAGMENTS. SOMETHING IS LISTENING.", 5.0)
    if not OS.has_feature("mobile"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _mat(c: Color, glow := false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = 0.95
    if glow:
        m.emission_enabled = true
        m.emission = c
        m.emission_energy_multiplier = 2.0
    return m

func _solid(n: String, p: Vector3, s: Vector3, c: Color) -> StaticBody3D:
    var b := StaticBody3D.new()
    b.name = n
    b.position = p
    var mesh := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = s
    mesh.mesh = bm
    mesh.material_override = _mat(c)
    b.add_child(mesh)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = s
    cs.shape = sh
    b.add_child(cs)
    add_child(b)
    return b

func _world() -> void:
    var we := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0.008, 0.012, 0.016)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.16, 0.18, 0.2)
    e.ambient_light_energy = 0.22
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    we.environment = e
    add_child(we)
    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-50, -25, 0)
    moon.light_color = Color(0.2, 0.26, 0.34)
    moon.light_energy = 0.12
    moon.shadow_enabled = true
    add_child(moon)
    _solid("Forest floor", Vector3(0,-0.4,0), Vector3(44,0.8,44), Color(0.045,0.055,0.052))
    for i in range(18):
        var z := -19.0 + float(i)*2.25
        _solid("Path", Vector3(0,0,z), Vector3(3.2,0.08,2.0), Color(0.09,0.1,0.095))
        for side in [-1.0,1.0]:
            var x := side*(3.3+float((i*7)%5)*0.65)
            _tree(Vector3(x,0,z+float((i*3)%4)*0.45),0.8+float(i%3)*0.15)
    # Ruined radio outpost
    _solid("Outpost floor",Vector3(0,0,-13),Vector3(11,0.25,8),Color(0.12,0.13,0.13))
    _solid("Back wall",Vector3(0,2,-17),Vector3(11,4,0.3),Color(0.09,0.1,0.11))
    _solid("Left wall",Vector3(-5.4,2,-13),Vector3(0.3,4,8),Color(0.1,0.1,0.11))
    _solid("Right wall",Vector3(5.4,2,-13),Vector3(0.3,4,8),Color(0.1,0.1,0.11))
    _solid("Roof beam",Vector3(0,4.1,-13),Vector3(11,0.25,8),Color(0.06,0.07,0.08))
    _solid("Desk",Vector3(0,0.85,-14),Vector3(2.4,0.18,0.8),Color(0.18,0.12,0.08))
    _lamp(Vector3(0,3.0,-13),Color(0.8,0.08,0.025),1.2,5.0)
    _lamp(Vector3(-4.8,2.5,-12),Color(0.08,0.25,0.5),0.65,4.0)
    _fragment(Vector3(-2.1,0.5,-5.0))
    _fragment(Vector3(3.3,0.5,-11.5))
    _fragment(Vector3(0,0.5,-15.0))
    _monster()

func _tree(p: Vector3, sc: float) -> void:
    var trunk := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.1*sc
    cm.bottom_radius = 0.28*sc
    cm.height = 2.7*sc
    trunk.mesh = cm
    trunk.position = p+Vector3(0,1.0*sc,0)
    trunk.material_override = _mat(Color(0.07,0.055,0.045))
    add_child(trunk)
    for j in range(3):
        var leaves := MeshInstance3D.new()
        var cone := PrismMesh.new()
        cone.size = Vector3(1.8*sc,1.55*sc,1.8*sc)
        leaves.mesh = cone
        leaves.position = p+Vector3(0,(2.0+0.65*j)*sc,0)
        leaves.rotation_degrees.y = j*51
        leaves.material_override = _mat(Color(0.012,0.03,0.026))
        add_child(leaves)

func _lamp(p: Vector3,c: Color,power: float,reach: float) -> void:
    var l := OmniLight3D.new()
    l.position = p
    l.light_color = c
    l.light_energy = power
    l.omni_range = reach
    l.shadow_enabled = true
    add_child(l)

func _fragment(p: Vector3) -> void:
    var a := Area3D.new()
    a.position = p
    var m := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.16
    sm.height = 0.32
    m.mesh = sm
    m.material_override = _mat(Color(0.9,0.055,0.02),true)
    a.add_child(m)
    var light := OmniLight3D.new()
    light.light_color = Color(0.8,0.035,0.01)
    light.light_energy = 0.4
    light.omni_range = 2.0
    a.add_child(light)
    var cs := CollisionShape3D.new()
    var ss := SphereShape3D.new()
    ss.radius = 0.75
    cs.shape = ss
    a.add_child(cs)
    a.set_meta("taken",false)
    collectibles.append(a)
    add_child(a)

func _monster() -> void:
    monster = Node3D.new()
    monster.position = Vector3(0,0,-19)
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.42
    capsule.height = 2.1
    body.mesh = capsule
    body.position.y = 1.05
    body.material_override = _mat(Color(0.012,0.006,0.01))
    monster.add_child(body)
    for x in [-0.14,0.14]:
        var eye := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 0.055
        eye.mesh = sphere
        eye.position = Vector3(x,1.48,-0.36)
        eye.material_override = _mat(Color(1,0.015,0.005),true)
        monster.add_child(eye)
    add_child(monster)

func _player() -> void:
    player = CharacterBody3D.new()
    player.position = Vector3(0,0.1,4)
    var cs := CollisionShape3D.new()
    var cap := CapsuleShape3D.new()
    cap.radius = 0.34
    cap.height = 1.7
    cs.shape = cap
    cs.position.y = 0.85
    player.add_child(cs)
    camera = Camera3D.new()
    camera.position.y = 1.55
    camera.fov = 78
    player.add_child(camera)
    flashlight = SpotLight3D.new()
    flashlight.light_color = Color(0.78,0.87,1)
    flashlight.light_energy = 3
    flashlight.spot_range = 18
    flashlight.spot_angle = 38
    flashlight.shadow_enabled = true
    camera.add_child(flashlight)
    add_child(player)

func _button(parent: Control, text_value: String, pos: Vector2, size: Vector2, kind: String) -> Button:
    var b := Button.new()
    b.text = text_value
    b.position = pos
    b.size = size
    b.set_meta("kind",kind)
    b.add_theme_font_size_override("font_size",15)
    b.add_theme_color_override("font_color",Color(0.95,0.95,0.95))
    var st := StyleBoxFlat.new()
    st.bg_color = Color(0.16,0.06,0.055,0.82)
    st.border_color = Color(0.72,0.12,0.08,0.8)
    st.set_border_width_all(1)
    st.set_corner_radius_all(16)
    b.add_theme_stylebox_override("normal",st)
    parent.add_child(b)
    b.button_down.connect(_button_down.bind(b))
    b.button_up.connect(_button_up.bind(b))
    return b

func _ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(root)
    hud := Label.new()
    hud.position = Vector2(20,18)
    hud.add_theme_font_size_override("font_size",18)
    hud.add_theme_color_override("font_color",Color(0.85,0.88,0.9))
    root.add_child(hud)
    message = Label.new()
    message.anchor_left = 0.12
    message.anchor_right = 0.88
    message.anchor_top = 0.1
    message.anchor_bottom = 0.22
    message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    message.add_theme_font_size_override("font_size",20)
    message.add_theme_color_override("font_color",Color(1,0.22,0.12))
    root.add_child(message)
    var cross := Label.new()
    cross.text = "+"
    cross.set_anchors_preset(Control.PRESET_CENTER)
    cross.position = Vector2(-6,-14)
    cross.add_theme_font_size_override("font_size",22)
    cross.add_theme_color_override("font_color",Color(0.8,0.82,0.84,0.8))
    root.add_child(cross)
    var brand := Label.new()
    brand.text = "BLACKOUT  /  LAST SIGNAL"
    brand.anchor_left = 0.03
    brand.anchor_top = 0.91
    brand.add_theme_font_size_override("font_size",13)
    brand.add_theme_color_override("font_color",Color(0.6,0.63,0.66,0.8))
    root.add_child(brand)
    _button(root,"MOVE",Vector2(35,-155),Vector2(145,120),"move").set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    _button(root,"RUN",Vector2(-165,-92),Vector2(100,62),"run").set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    _button(root,"USE",Vector2(-165,-165),Vector2(100,62),"use").set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    _button(root,"LIGHT",Vector2(-280,-92),Vector2(100,62),"light").set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    var look := Control.new()
    look.anchor_left = 0.38
    look.anchor_right = 1
    look.anchor_top = 0.22
    look.anchor_bottom = 1
    look.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(look)
    look.gui_input.connect(_look_input)

func _button_down(b: Button) -> void:
    match b.get_meta("kind"):
        "run": sprinting = true
        "use": _interact()
        "light": flashlight.visible = not flashlight.visible
        "move": move_vec = Vector2(0,-1)

func _button_up(b: Button) -> void:
    if b.get_meta("kind") == "run": sprinting = false
    if b.get_meta("kind") == "move": move_vec = Vector2.ZERO

func _look_input(ev: InputEvent) -> void:
    if ev is InputEventScreenTouch:
        if ev.pressed:
            look_id = ev.index
            last_pos = ev.position
        elif ev.index == look_id:
            look_id = -1
    elif ev is InputEventScreenDrag and ev.index == look_id:
        var d := ev.position-last_pos
        player.rotate_y(-d.x*0.0022)
        camera.rotate_x(-d.y*0.0022)
        camera.rotation.x = clamp(camera.rotation.x,-1.3,1.3)
        last_pos = ev.position

func _unhandled_input(ev: InputEvent) -> void:
    if ev is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        player.rotate_y(-ev.relative.x*0.0022)
        camera.rotate_x(-ev.relative.y*0.0022)
        camera.rotation.x = clamp(camera.rotation.x,-1.3,1.3)
    if ev is InputEventKey and ev.pressed:
        if ev.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        if ev.keycode == KEY_E: _interact()

func _process(delta: float) -> void:
    if ended: return
    for item in collectibles:
        if is_instance_valid(item) and not item.get_meta("taken"):
            item.rotate_y(delta*0.9)
            item.position.y = 0.5+sin(Time.get_ticks_msec()*0.002+item.position.z)*0.08
    hud.text = "SIGNAL  %d/3     STAMINA  %d%%" % [fragments,int(stamina)]
    if fragments >= 3 and player.global_position.distance_to(Vector3(0,0,4)) < 1.8:
        _finish(true)
    if fragments > 0 and player.global_position.distance_to(monster.global_position) < 1.7:
        _finish(false)
    if fragments < 3 and player.global_position.distance_to(monster.global_position) > 5:
        var target := player.global_position
        target.y = 0
        monster.look_at(Vector3(target.x,1,target.z),Vector3.UP)
        monster.position = monster.position.move_toward(Vector3(target.x,0,target.z),delta*0.45)

func _physics_process(delta: float) -> void:
    if ended: return
    var v := Vector2.ZERO
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
    v += move_vec
    v = v.limit_length(1)
    var dir := (player.transform.basis*Vector3(v.x,0,v.y)).normalized()
    var running := sprinting or Input.is_key_pressed(KEY_SHIFT)
    var speed := 5.0 if running and stamina > 0 else 3.1
    if running and v.length()>0.1: stamina=max(0,stamina-delta*22)
    else: stamina=min(100,stamina+delta*13)
    player.velocity.x=dir.x*speed
    player.velocity.z=dir.z*speed
    if not player.is_on_floor(): player.velocity.y-=18*delta
    player.move_and_slide()

func _interact() -> void:
    if ended: return
    var from := camera.global_position
    var to := from-camera.global_transform.basis.z*2.6
    var query := PhysicsRayQueryParameters3D.create(from,to)
    query.exclude=[player]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    var found: Area3D
    if hit and hit.collider is Area3D and hit.collider in collectibles:
        found=hit.collider
    else:
        var nearest := 999.0
        for item in collectibles:
            if not item.get_meta("taken"):
                var d := camera.global_position.distance_to(item.global_position)
                if d < nearest and d < 2.1:
                    nearest=d
                    found=item
    if is_instance_valid(found) and not found.get_meta("taken"):
        found.set_meta("taken",true)
        found.queue_free()
        fragments+=1
        _say("SIGNAL FRAGMENT RECOVERED  %d/3" % fragments,2.2)
        if fragments == 3: _say("ALL FRAGMENTS FOUND. RETURN TO THE RED LIGHT.",4)
    else:
        _say("NOTHING HERE. KEEP LOOKING.",1.5)

func _say(t: String, duration: float) -> void:
    if not is_instance_valid(message): return
    message.text=t
    message.visible=true
    await get_tree().create_timer(duration).timeout
    if is_instance_valid(message) and message.text==t: message.visible=false

func _finish(win: bool) -> void:
    ended=true
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    var panel := ColorRect.new()
    panel.color=Color(0.005,0.007,0.01,0.96)
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    get_node("CanvasLayer").add_child(panel)
    var label := Label.new()
    label.text="SIGNAL RESTORED\nYOU SURVIVED" if win else "THE LISTENER FOUND YOU\nSIGNAL LOST"
    label.set_anchors_preset(Control.PRESET_CENTER)
    label.position=Vector2(-300,-100)
    label.size=Vector2(600,180)
    label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size",30)
    label.add_theme_color_override("font_color",Color(0.95,0.12,0.07))
    panel.add_child(label)
    var retry := Button.new()
    retry.text="PLAY AGAIN"
    retry.size=Vector2(200,58)
    retry.position=Vector2(-100,100)
    retry.set_anchors_preset(Control.PRESET_CENTER)
    panel.add_child(retry)
    retry.pressed.connect(func(): get_tree().reload_current_scene())
