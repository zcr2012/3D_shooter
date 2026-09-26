"""Fictional compact carbine visual asset. Local grip points stay compatible."""
import bpy, math
from mathutils import Vector, Matrix, Euler
from v08_geometry import Builder

def make_weapon(mat,rig):
    b=Builder(); mag=Builder()
    # Graphic silhouette extruded across X, centimetre-scale external details.
    def profile(builder,yz,width,tile='metal',bevel=.003):
        temp=Builder(); temp.plate(yz,0,width,tile,bevel=bevel)
        off=len(builder.v)
        for p,uv in zip(temp.v,temp.uv): builder.vert((p[1],p[0],p[2]),uv,{})
        for f,s in zip(temp.f,temp.smooth): builder.face([off+i for i in f],s)
    def ring_y(builder,y,length,outer,inner,z=0,tile='metal',n=24):
        start=len(builder.v)
        for yy,rr in [(y-length/2,outer),(y+length/2,outer),(y-length/2,inner),(y+length/2,inner)]:
            for i in range(n):
                a=math.tau*i/n; builder.vert((rr*math.cos(a),yy,z+rr*math.sin(a)),builder.atlas((i/n,.5+yy),'metal'),{})
        for i in range(n):
            j=(i+1)%n
            builder.face((start+i,start+j,start+n+j,start+n+i))
            builder.face((start+2*n+j,start+2*n+i,start+3*n+i,start+3*n+j))
            builder.face((start+j,start+i,start+2*n+i,start+2*n+j),False)
            builder.face((start+n+i,start+n+j,start+3*n+j,start+3*n+i),False)
    # Two receiver halves with chamfered silhouettes and distinct seam.
    profile(b,[(-.10,-.018),(.102,-.018),(.128,.012),(.128,.039),(.095,.054),(-.083,.054),(-.112,.03)],.048,'metal',.004)
    profile(b,[(-.089,-.021),(.104,-.021),(.087,-.065),(.025,-.071),(.006,-.056),(-.071,-.055)],.043,'metal',.003)
    b.box((0,.014,.056),(.042,.211,.008),'metal',bevel=.002)
    # Barrel, collar and open muzzle bore. Keep bore visibly hollow.
    b.tube([(0,.118,.009),(0,.493,.009)],.010,'metal',n=20)
    ring_y(b,.388,.028,.017,.010,z=.009)
    ring_y(b,.486,.052,.019,.010,z=.009)
    # Handguard: rails and side straps form real open gaps around a darker core.
    b.box((0,.254,.037),(.06,.275,.016),'polymer',bevel=.004)
    b.box((0,.245,-.025),(.057,.256,.014),'polymer',bevel=.004)
    for sx in [-1,1]:
        b.box((sx*.033,.244,.001),(.012,.264,.023),'metal',bevel=.003)
        for yy in [.148,.19,.232,.274,.316,.358]:
            b.box((sx*.031,yy,.017),(.013,.014,.04),'metal',bevel=.002)
            b.box((sx*.04,yy,-.006),(.006,.026,.011),'rubber',bevel=.002)
        # Side control/receiver hardware.
        b.box((sx*.026,.028,.018),(.004,.062,.026),'rubber',bevel=.002)
        b.box((sx*.029,.025,.015),(.003,.052,.016),'metal',bevel=.002)
        for yy,zz in [(-.067,-.029),(.068,-.026),(-.086,.019)]:
            b.tube([(sx*.025,yy,zz),(sx*.03,yy,zz)],.005,'metal',n=10)
            b.box((sx*.031,yy,zz),(.001,.006,.0015),'rubber',bevel=0)
        b.box((sx*.027,-.075,.006),(.005,.028,.007),'polymer',bevel=.002,rot=Euler((.0,.0,.3)))
    # Picatinny rail teeth; detail beyond the old silhouette.
    for i in range(24):
        y=-.087+i*.019
        b.box((0,y,.065),(.038,.011,.009),'metal',bevel=.001)
    # Buffer tube and sloped adjustable stock with cheek rest / rubber pad.
    b.tube([(0,-.097,.015),(0,-.31,.015)],.014,'metal',n=16)
    profile(b,[(-.326,-.071),(-.29,-.062),(-.188,.012),(-.163,.025),(-.18,.045),(-.31,.049),(-.335,.034)],.045,'polymer',.006)
    b.box((0,-.258,.049),(.054,.126,.02),'polymer',bevel=.007)
    b.box((0,-.337,-.009),(.055,.019,.133),'rubber',bevel=.005,rot=Euler((-.13,0,0)))
    for z in [-.059,-.04,-.021,-.002,.017,.036]: b.box((0,-.35,z),(.049,.003,.006),'rubber',bevel=.001)
    b.box((0,-.242,-.027),(.027,.064,.012),'metal',bevel=.003)
    # Pistol grip keeps the old hand target at (0,-.055,-.098).
    profile(b,[(-.079,-.041),(-.035,-.048),(-.053,-.151),(-.092,-.148)],.035,'polymer',.005)
    for sx in [-1,1]:
        for z in [-.077,-.091,-.105,-.119,-.133]: b.box((sx*.019,-.065,z),(.004,.034,.004),'rubber',bevel=.001)
    # Closed exterior trigger guard, represented as a curve; no functional internals.
    b.tube([(-.019,-.031,-.052),(-.019,-.028,-.094),(-.019,.019,-.094),(-.019,.035,-.06)],.003,'metal',n=7)
    b.tube([(.019,-.031,-.052),(.019,-.028,-.094),(.019,.019,-.094),(.019,.035,-.06)],.003,'metal',n=7)
    b.tube([(0,-.007,-.052),(0,-.005,-.073),(0,.008,-.079)],.0025,'metal',n=7)
    # Compact tubular optic, mount, capped turrets and coated lens inset.
    b.box((0,.045,.078),(.038,.09,.026),'metal',bevel=.004)
    ring_y(b,.06,.08,.025,.019,z=.119)
    ring_y(b,.014,.015,.027,.018,z=.119)
    ring_y(b,.105,.015,.027,.018,z=.119)
    b.tube([(0,.10,.119),(0,.103,.119)],.018,'lens',n=24)
    b.tube([(.018,.059,.119),(.034,.059,.119)],.009,'polymer',n=14)
    b.tube([(0,.059,.14),(0,.059,.152)],.009,'polymer',n=14)
    # Front sight and side lamp with cable, restrained in size.
    b.box((0,.342,.083),(.017,.016,.037),'metal',bevel=.002)
    b.tube([(.052,.20,-.002),(.052,.298,-.002)],.013,'polymer',n=16)
    b.tube([(.052,.298,-.002),(.052,.305,-.002)],.014,'lens',n=16)
    b.box((.038,.246,-.002),(.02,.048,.021),'metal',bevel=.003)
    b.tube([(.05,.19,0),(.062,.175,.018),(.04,.17,.03),(.037,.20,.035)],.002,'rubber',n=7)
    # Curved polymer magazine as continuous cross-section rings, separate bone.
    profile(mag,[(-.026,-.06),(.083,-.06),(.075,-.13),(.045,-.229),(-.012,-.24),(-.037,-.208),(-.03,-.138)],.031,'polymer',.005)
    bbase=[(-.037,-.208),(.045,-.229),(.043,-.244),(-.014,-.254),(-.043,-.222)]
    profile(mag,bbase,.039,'rubber',.003)
    for sx in [-1,1]:
        for z,cy in [(-.102,.023),(-.13,.019),(-.158,.011),(-.186,.003),(-.213,-.004)]:
            mag.box((sx*.017,cy,z),(.003,.07,.006),'rubber',bevel=.001)
        for y in [-.011,.011,.033]:
            mag.tube([(sx*.018,y,-.086),(sx*.018,y-.005,-.135),(sx*.018,y-.019,-.205)],.002,'metal',n=5)
    result=[]
    for name,builder,bone in [('AR_AssaultRifle',b,'weapon_root'),('AR_Magazine',mag,'weapon_mag')]:
        old=bpy.data.objects.get(name)
        if old: bpy.data.objects.remove(old,do_unlink=True)
        ob=builder.object(name,mat)
        ob.parent=rig; ob.parent_type='BONE'; ob.parent_bone=bone
        ob.matrix_parent_inverse=Matrix.Identity(4); ob.matrix_basis=Matrix.Translation((0,-.1,0))
        ob['asset_version']='v08'; result.append(ob)
    return result
