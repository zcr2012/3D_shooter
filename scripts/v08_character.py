"""A tailored tactical silhouette, retaining the v07 motion skeleton/actions."""
import bpy, math
from mathutils import Vector, Matrix, Euler
from v08_geometry import Builder

def make_character(mat,rig):
    b=Builder(); D=math.radians
    bones=rig.data.bones
    def rigid(n): return {n:1}
    def skin(names,p):
        ws=[]
        for n in names:
            bone=bones[n]; d=bone.tail_local-bone.head_local
            t=max(0,min(1,(p-bone.head_local).dot(d)/d.length_squared))
            distance=(p-bone.head_local-t*d).length
            ws.append((n,1/(distance+.02)**5))
        total=sum(w for n,w in ws)
        return {n:w/total for n,w in ws if w/total>.003}
    torso=lambda p:skin(['hip','spine','chest','neck'],p)
    # Cloth: believable volumes with extra rings around articulating joints.
    b.loft([(0,0,.87,.142,.104),(0,0,.94,.153,.115),(0,0,1.02,.142,.105),
        (0,0,1.10,.147,.11),(0,0,1.19,.167,.119),(0,0,1.28,.179,.118),
        (0,0,1.36,.194,.105),(0,0,1.39,.165,.082),(0,0,1.415,.076,.066)],'cloth',torso,n=32,fold=.025)
    b.loft([(0,0,1.37,.062,.059),(0,0,1.44,.057,.056),(0,0,1.485,.054,.052)],'cloth',lambda p:skin(['chest','neck','head'],p),n=24)
    # Cover the lower face with a fitted balaclava. No exposed placeholder face.
    b.loft([(0,-.008,1.425,.045,.047),(0,.016,1.465,.065,.071),(0,.015,1.505,.078,.085),
        (0,.003,1.555,.087,.092),(0,-.007,1.615,.083,.090),(0,-.012,1.658,.055,.065)],'cloth',rigid('head'),n=28)
    # Nose/respirator contour, not a large box on the face.
    b.ellipsoid((0,.083,1.505),(.049,.03,.041),'cloth',rigid('head'),n=20,rings=8)
    # Molded high-cut helmet dome with curved lower lip.
    dome=[(0,-.005,1.577,.096,.108),(0,-.008,1.591,.104,.115),(0,-.011,1.62,.103,.116),
          (0,-.016,1.652,.095,.107),(0,-.019,1.675,.075,.089),(0,-.019,1.688,.043,.056),
          (0,-.019,1.692,.004,.007)]
    b.loft(dome,'polymer',rigid('head'),n=32)
    # Rim, fabric cover seams and restrained hardware.
    rim=[(.099*math.cos(a),-.008+.112*math.sin(a),1.589) for a in [i*math.tau/32 for i in range(33)]]
    b.tube(rim,.003,'rubber',rigid('head'),n=6)
    for sx in [-1,1]:
        b.box((sx*.102,-.014,1.602),(.012,.073,.022),'metal',rigid('head'),.002)
        for y in [-.033,-.008,.017]:
            b.ellipsoid((sx*.109,y,1.603),(.004,.004,.004),'mark',rigid('head'),n=8,rings=4)
        # Ear cups and helmet retention straps.
        b.ellipsoid((sx*.096,-.025,1.533),(.019,.035,.043),'polymer',rigid('head'),n=16,rings=8)
        b.tube([(sx*.073,.05,1.595),(sx*.08,.049,1.526),(sx*.046,.054,1.461)],.005,'webbing',rigid('head'),n=6)
    b.box((0,.105,1.634),(.034,.013,.034),'metal',rigid('head'),.003)
    b.box((0,.115,1.636),(.019,.008,.018),'polymer',rigid('head'),.002)
    # Ballistic goggles, curved frame approximated with two low convex lenses.
    b.ellipsoid((0,.091,1.558),(.087,.026,.03),'rubber',rigid('head'),n=28,rings=8)
    for sx in [-1,1]:
        b.ellipsoid((sx*.036,.111,1.558),(.033,.005,.018),'lens',rigid('head'),n=20,rings=6)
    b.tube([(-.082,.082,1.56),(-.093,-.035,1.564),(0,-.106,1.561),(.093,-.035,1.564),(.082,.082,1.56)],.009,'webbing',rigid('head'),n=6)
    # Front/back anatomically cut plate carriers, layered rather than giant cuboids.
    outline=[(-.15,1.125),(.15,1.125),(.163,1.265),(.101,1.366),(-.101,1.366),(-.163,1.265)]
    b.plate(outline,.137,.048,'webbing',rigid('chest'),.009)
    b.plate(outline,-.13,.042,'webbing',rigid('chest'),.008)
    for sx in [-1,1]:
        b.box((sx*.14,0,1.17),(.035,.236,.084),'webbing',rigid('chest'),.006)
        b.tube([(sx*.085,.13,1.36),(sx*.095,.072,1.413),(sx*.095,-.035,1.424),(sx*.085,-.13,1.36)],.023,'webbing',rigid('chest'),n=8)
        b.box((sx*.086,.153,1.337),(.037,.017,.039),'polymer',rigid('chest'),.003)
    # MOLLE horizontal webbing and stitched bar-tacks; low profile.
    for row,z in enumerate([1.17,1.201,1.232,1.263]):
        b.box((0,.164,z),(.286,.006,.012),'webbing',rigid('chest'),.001)
        b.box((0,-.156,z),(.276,.005,.012),'webbing',rigid('chest'),.001)
        for x in [-.124,-.082,-.041,0,.041,.082,.124]:
            b.box((x,.169,z),(.002,.002,.011),'mark',rigid('chest'),.0004)
    # Three shaped magazine pouches with visible top lips and retention cords.
    for x in [-.09,0,.09]:
        b.box((x,.186,1.182),(.079,.049,.137),'webbing',rigid('chest'),.008)
        b.box((x,.19,1.248),(.068,.034,.018),'polymer',rigid('chest'),.003)
        b.tube([(x-.025,.207,1.232),(x-.02,.22,1.262),(x+.02,.22,1.262),(x+.025,.207,1.232)],.0025,'rubber',rigid('chest'),n=6)
        b.box((x,.213,1.18),(.066,.006,.055),'webbing',rigid('chest'),.003)
    b.box((.124,.176,1.315),(.043,.039,.079),'polymer',rigid('chest'),.005)
    b.tube([(.135,.176,1.35),(.14,.171,1.425)],.003,'rubber',rigid('chest'),n=8)
    # Back admin pouch and hydration unit, breaks flat backpack silhouette.
    b.box((0,-.173,1.268),(.18,.054,.142),'webbing',rigid('chest'),.012)
    # Sewn identification patch with real text geometry, not a post-render label.
    patch=Builder(); patch.box((0,-.163,1.351),(.136,.008,.034),'rubber',rigid('chest'),.003)
    offset=len(b.v)
    for p,uv,w in zip(patch.v,patch.uv,patch.w): b.vert(p,uv,w)
    for face,sm in zip(patch.f,patch.smooth): b.face([offset+i for i in face],sm)
    curve=bpy.data.curves.new('_IDPatch','FONT'); curve.body='SWAT'; curve.align_x='CENTER'; curve.size=.024; curve.extrude=.0003
    text=bpy.data.objects.new('_IDPatch',curve); bpy.context.scene.collection.objects.link(text)
    text.location=(0,-.169,1.341); text.rotation_euler=(D(90),0,D(180)); text.scale.x=-1
    bpy.context.view_layer.update()
    dg=bpy.context.evaluated_depsgraph_get(); ev=text.evaluated_get(dg); mesh=ev.to_mesh()
    b.append_mesh(mesh,'mark',rigid('chest'),text.matrix_world)
    ev.to_mesh_clear(); bpy.data.objects.remove(text,do_unlink=True)
    for x in [-.058,.058]: b.box((x,-.204,1.27),(.019,.006,.119),'webbing',rigid('chest'),.001)
    b.tube([(.087,-.176,1.33),(.123,-.096,1.398),(.14,.05,1.414),(.125,.159,1.33)],.004,'rubber',rigid('chest'),n=7)
    # Duty belt, buckle, belt loops and lumbar pouch.
    b.loft([(0,0,.945,.155,.116),(0,0,.985,.156,.117)],'webbing',rigid('hip'),n=32)
    b.box((0,.12,.966),(.047,.014,.033),'metal',rigid('hip'),.004)
    for x in [-.113,-.065,.065,.113]: b.box((x,.095,.966),(.013,.027,.048),'webbing',rigid('hip'),.003)
    b.box((.162,-.052,.955),(.06,.065,.09),'webbing',rigid('hip'),.008)
    b.box((0,-.129,.932),(.09,.051,.082),'webbing',rigid('hip'),.006)
    for side,sx in [('L',1),('R',-1)]:
        leg=lambda p,side=side: skin(['hip','thigh.'+side,'shin.'+side,'foot.'+side],p)
        arm=lambda p,side=side: skin(['shoulder.'+side,'upperarm.'+side,'forearm.'+side,'hand.'+side],p)
        # Pants: roomy upper leg, darted knee, tapered ankle with layered folds.
        b.loft([(sx*.111,.001,.15,.059,.059),(sx*.111,.001,.20,.065,.066),
            (sx*.11,.002,.27,.07,.072),(sx*.11,.005,.35,.072,.075),
            (sx*.11,.007,.425,.071,.075),(sx*.11,.004,.47,.069,.071),
            (sx*.108,.003,.50,.073,.075),(sx*.107,.004,.535,.078,.078),
            (sx*.106,.004,.585,.087,.085),(sx*.103,.003,.66,.092,.091),
            (sx*.10,.004,.75,.094,.094),(sx*.096,.002,.835,.091,.099),(sx*.091,0,.915,.085,.097)],
            'cloth',leg,n=24,fold=.045,phase=sx)
        # Raised side seam and double-stitched cargo flap edges.
        b.tube([(sx*.181,-.006,.79),(sx*.191,-.005,.69),(sx*.178,-.005,.59)],.0016,'webbing',leg,n=5)
        # Cargo pockets intentionally only on upper thigh, no long box over knee.
        b.box((sx*.192,.0,.72),(.03,.118,.137),'cloth',rigid('thigh.'+side),.009)
        b.box((sx*.208,.0,.774),(.012,.118,.036),'webbing',rigid('thigh.'+side),.004)
        b.box((sx*.185,.055,.62),(.03,.03,.06),'webbing',rigid('thigh.'+side),.005)
        # Molded articulated knee shield, tibia attachment.
        b.ellipsoid((sx*.11,.073,.48),(.061,.027,.075),'polymer',rigid('shin.'+side),n=20,rings=9)
        b.ellipsoid((sx*.11,.097,.478),(.038,.011,.041),'rubber',rigid('shin.'+side),n=16,rings=6)
        # Sleeves: broaden deltoid and forearm silhouette without changing skeleton.
        b.loft([(sx*.254,.005,.89,.041,.043),(sx*.25,.004,.92,.044,.046),
            (sx*.244,.004,.976,.056,.057),(sx*.239,.004,1.035,.06,.064),
            (sx*.23,.004,1.083,.062,.063),(sx*.224,.004,1.115,.066,.065),
            (sx*.217,.004,1.162,.072,.071),(sx*.198,.004,1.24,.078,.077),
            (sx*.172,.004,1.32,.085,.083),(sx*.154,.004,1.375,.082,.078),
            (sx*.147,.004,1.412,.064,.063),(sx*.137,.004,1.433,.01,.013)],'cloth',arm,n=24,fold=.045,phase=sx+1)
        b.box((sx*.238,-.05,1.095),(.096,.033,.089),'polymer',rigid('forearm.'+side),.017)
        b.loft([(sx*.254,.004,.885,.043,.044),(sx*.252,.004,.925,.046,.048)],'webbing',rigid('forearm.'+side),n=20)
        b.box((sx*.205,.067,1.283),(.065,.024,.08),'webbing',rigid('upperarm.'+side),.007)
        # Boot footprint with heel/toe taper, ankle shaft and rubber sole.
        foot=rigid('foot.'+side)
        def boot_rings(zs):
            start=len(b.v); outline=[(-.041,-.07),(.041,-.07),(.058,-.043),(.059,.07),(.047,.145),(.029,.161),(-.029,.161),(-.047,.145),(-.059,.07),(-.058,-.043)]
            for z,scal,yoff in zs:
                for i,(x,y) in enumerate(outline): b.vert((sx*.11+x*scal,y+yoff,z),b.atlas((i/len(outline),(z-.003)/.12),'rubber' if z<.028 else 'glove'),foot)
            n=len(outline)
            for j in range(len(zs)-1):
                for i in range(n): b.face((start+j*n+i,start+j*n+(i+1)%n,start+(j+1)*n+(i+1)%n,start+(j+1)*n+i))
            b.face(tuple(start+i for i in reversed(range(n))),False)
            b.face(tuple(start+(len(zs)-1)*n+i for i in range(n)),False)
        boot_rings([(.003,1,0),(.013,1.015,0),(.024,1,0),(.05,.96,-.005),(.06,.94,-.003),(.078,.85,-.006),(.096,.57,-.02)])
        b.loft([(sx*.11,-.023,.049,.052,.071),(sx*.11,-.026,.10,.048,.060),
            (sx*.11,-.01,.145,.054,.061),(sx*.11,-.001,.175,.055,.06)],'glove',foot,n=20)
        b.box((sx*.11,.027,.14),(.048,.02,.099),'glove',foot,.008)
        for z in [.099,.119,.139,.159,.179]:
            b.tube([(sx*.11-.021,.040,z),(sx*.11+.021,.041,z+.012)],.0018,'mark',foot,n=5)
            b.tube([(sx*.11+.021,.040,z),(sx*.11-.021,.041,z+.012)],.0018,'mark',foot,n=5)
        for yy in [-.05,-.012,.026,.064,.10,.132]:
            b.box((sx*.11,yy,.014),(.119,.011,.015),'rubber',foot,.002)
    # Gloves are constructed around the actual idle grip, inverse skinned back
    # into rest space. Their silhouette follows the authored hand motion.
    rig.animation_data.action=bpy.data.actions['IdleArmed']; bpy.context.scene.frame_set(0); bpy.context.view_layer.update()
    weapon=rig.pose.bones['weapon_root'].matrix
    for side in ['R','L']:
        hand='hand.'+side; g=Builder()
        if side=='R':
            g.ellipsoid((-.025,-.056,-.092),(.026,.029,.038),'glove',rigid(hand),n=18,rings=8)
            for j,z in enumerate([-.075,-.091,-.107,-.123]):
                g.tube([(-.031,-.067,z),(-.03,-.031,z),(-.01,-.017,z),( .011,-.027,z)],.0075,'glove',rigid(hand),n=8)
            g.tube([(-.028,-.075,-.06),(-.003,-.09,-.068),(.014,-.067,-.077)],.011,'glove',rigid(hand),n=9)
            g.ellipsoid((-.046,-.05,-.09),(.009,.022,.023),'polymer',rigid(hand),n=14,rings=6)
        else:
            g.ellipsoid((.02,.183,-.04),(.024,.032,.019),'glove',rigid(hand),n=18,rings=8)
            for y in [.16,.176,.192,.208]:
                g.tube([(.035,y,-.038),(.021,y,-.058),(-.009,y,-.061),(-.025,y,-.038)],.007,'glove',rigid(hand),n=8)
            g.tube([(.023,.16,-.023),(.032,.182,-.006),(.01,.192,.002)],.009,'glove',rigid(hand),n=9)
        inv=(rig.pose.bones[hand].matrix @ bones[hand].matrix_local.inverted()).inverted()
        offset=len(b.v)
        for p,uv,w in zip(g.v,g.uv,g.w): b.vert(inv@weapon@Vector(p),uv,w)
        for face,sm in zip(g.f,g.smooth): b.face([offset+i for i in face],sm)
    old=bpy.data.objects.get('SWAT_Operator')
    if old: bpy.data.objects.remove(old,do_unlink=True)
    ob=b.object('SWAT_Operator',mat,rig)
    ob['asset_version']='v08'; ob['surface_source']='Authored geometry / packed PBR swatch atlas'
    return ob
