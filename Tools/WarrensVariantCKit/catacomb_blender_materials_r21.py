"""Analytic Blender counterparts of the accepted native timber and ivory graphs."""
PREFIX='CP21_'
def base(name,colour,roughness,metallic=0):
    import bpy
    assert PREFIX+name not in bpy.data.materials
    m=bpy.data.materials.new(PREFIX+name);m.use_nodes=True;m.diffuse_color=tuple(colour)+(1,)
    t=m.node_tree;t.nodes.clear();bs=t.nodes.new('ShaderNodeBsdfPrincipled');bs.inputs['Base Color'].default_value=tuple(colour)+(1,);bs.inputs['Roughness'].default_value=roughness;bs.inputs['Metallic'].default_value=metallic
    out=t.nodes.new('ShaderNodeOutputMaterial');t.links.new(bs.outputs['BSDF'],out.inputs['Surface']);return m,t,bs
def scalar(t,op,*values):
    n=t.nodes.new('ShaderNodeMath');n.operation=op
    for i,v in enumerate(values):
        if hasattr(v,'is_output'):t.links.new(v,n.inputs[i])
        else:n.inputs[i].default_value=float(v)
    return n.outputs[0]
def colour_mix(t,factor,a,b):
    n=t.nodes.new('ShaderNodeMixRGB');n.blend_type='MIX';t.links.new(factor,n.inputs[0])
    for i,v in ((1,a),(2,b)):
        if hasattr(v,'is_output'):t.links.new(v,n.inputs[i])
        else:n.inputs[i].default_value=tuple(v)+(1,)
    return n.outputs['Color']
def timber(role):
    assert role in ('Post','Arm');m,t,bs=base('Timber'+role,(.100,.052,.024),.86)
    tc=t.nodes.new('ShaderNodeTexCoord');xyz=t.nodes.new('ShaderNodeSeparateXYZ');t.links.new(tc.outputs['Generated'],xyz.inputs[0]);x,y,z=[xyz.outputs[k] for k in 'XYZ']
    length,a,b=(z,x,y) if role=='Post' else (x,y,z)
    choose=scalar(t,'GREATER_THAN',scalar(t,'ABSOLUTE',scalar(t,'SUBTRACT',a,.5)),scalar(t,'ABSOLUTE',scalar(t,'SUBTRACT',b,.5)))
    q=scalar(t,'ADD',scalar(t,'MULTIPLY',a,scalar(t,'SUBTRACT',1,choose)),scalar(t,'MULTIPLY',b,choose))
    dark=scalar(t,'MULTIPLY',scalar(t,'LESS_THAN',length,.76),scalar(t,'LESS_THAN',q,scalar(t,'ADD',.12,scalar(t,'MULTIPLY',.26,length))))
    light=scalar(t,'MULTIPLY',scalar(t,'GREATER_THAN',length,.20),scalar(t,'GREATER_THAN',q,scalar(t,'ADD',.64,scalar(t,'MULTIPLY',.10,scalar(t,'ABSOLUTE',scalar(t,'SUBTRACT',length,.37))))))
    patch=scalar(t,'MULTIPLY',scalar(t,'MULTIPLY',scalar(t,'GREATER_THAN',length,.72),scalar(t,'GREATER_THAN',q,.24)),scalar(t,'LESS_THAN',q,scalar(t,'ADD',.55,scalar(t,'MULTIPLY',.12,scalar(t,'SUBTRACT',length,.72)))))
    c=colour_mix(t,dark,(.100,.052,.024),(.082,.040,.018));c=colour_mix(t,light,c,(.118,.064,.030));c=colour_mix(t,patch,c,(.106,.050,.023));t.links.new(c,bs.inputs['Base Color'])
    assert not any(n.bl_idname=='ShaderNodeTexNoise' for n in t.nodes)
    m['NativeReference']='Forage_R04/Timber_R02/Materials/M_CP_ForageTimber'+role+'_R02';m['CoordinateContract']='Unit cube Generated0..1 = native PreSkinnedPositionCm*.01+.5; strict branch/tie order retained.'
    return m
def ivory(role,pigment,normal_gl):
    assert role in ('Bone','Urn');colour,roughness=((.36,.32,.24),.93) if role=='Bone' else ((.30,.265,.20),.84)
    m,t,bs=base('Ivory'+role,colour,roughness);geo=t.nodes.new('ShaderNodeNewGeometry')
    transforms=[]
    for kind,socket in (('POINT','Position'),('NORMAL','Normal')):
        n=t.nodes.new('ShaderNodeVectorTransform');n.vector_type=kind;n.convert_from='WORLD';n.convert_to='OBJECT';t.links.new(geo.outputs[socket],n.inputs['Vector']);transforms.append(n.outputs['Vector'])
    scale=t.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/.65;t.links.new(transforms[0],scale.inputs[0]);pos=t.nodes.new('ShaderNodeSeparateXYZ');t.links.new(scale.outputs['Vector'],pos.inputs[0])
    ns=t.nodes.new('ShaderNodeSeparateXYZ');t.links.new(transforms[1],ns.inputs[0]);weights=[scalar(t,'POWER',scalar(t,'ABSOLUTE',ns.outputs[k]),8) for k in 'XYZ'];den=scalar(t,'MAXIMUM',scalar(t,'ADD',scalar(t,'ADD',weights[0],weights[1]),weights[2]),.0001);weights=[scalar(t,'DIVIDE',v,den) for v in weights]
    projected=[]
    for axes,weight in zip(('YZ','XZ','XY'),weights):
        uv=t.nodes.new('ShaderNodeCombineXYZ');t.links.new(pos.outputs[axes[0]],uv.inputs['X']);t.links.new(pos.outputs[axes[1]],uv.inputs['Y'])
        tex=t.nodes.new('ShaderNodeTexImage');tex.image=pigment;tex.extension='REPEAT';t.links.new(uv.outputs[0],tex.inputs['Vector']);mul=t.nodes.new('ShaderNodeVectorMath');mul.operation='SCALE';t.links.new(tex.outputs['Color'],mul.inputs[0]);t.links.new(weight,mul.inputs['Scale']);projected.append(mul.outputs['Vector'])
    add=t.nodes.new('ShaderNodeVectorMath');add.operation='ADD';t.links.new(projected[0],add.inputs[0]);t.links.new(projected[1],add.inputs[1]);add2=t.nodes.new('ShaderNodeVectorMath');add2.operation='ADD';t.links.new(add.outputs['Vector'],add2.inputs[0]);t.links.new(projected[2],add2.inputs[1])
    channels=t.nodes.new('ShaderNodeSeparateColor');channels.mode='RGB';t.links.new(add2.outputs['Vector'],channels.inputs[0]);luma=scalar(t,'ADD',scalar(t,'ADD',scalar(t,'MULTIPLY',channels.outputs['Red'],.2126),scalar(t,'MULTIPLY',channels.outputs['Green'],.7152)),scalar(t,'MULTIPLY',channels.outputs['Blue'],.0722))
    value=scalar(t,'MINIMUM',scalar(t,'MAXIMUM',scalar(t,'DIVIDE',luma,.18),.5),1.5);gain=scalar(t,'ADD',.45,scalar(t,'MULTIPLY',.55,value))
    rgb=t.nodes.new('ShaderNodeCombineXYZ')
    for axis,v in zip('XYZ',colour):t.links.new(scalar(t,'MULTIPLY',gain,v),rgb.inputs[axis])
    t.links.new(rgb.outputs['Vector'],bs.inputs['Base Color'])
    normal=t.nodes.new('ShaderNodeTexImage');normal.image=normal_gl;normal.extension='REPEAT';nm=t.nodes.new('ShaderNodeNormalMap');nm.space='TANGENT';nm.inputs['Strength'].default_value=1;t.links.new(normal.outputs['Color'],nm.inputs['Color']);t.links.new(nm.outputs['Normal'],bs.inputs['Normal'])
    assert pigment.colorspace_settings.name=='sRGB' and normal_gl.colorspace_settings.name=='Non-Color'
    m['NativeReference']='Materials/MI_CP_'+role+'_R01';m['CoordinateContract']='Localobjectmetres/.65 and localnormal abs^8; bounded angular value gain; existingTX06 NormalGL/UV0 retained.'
    return m
def vertex_colour(role):
    assert role in ('Fruit','Bronze');m,t,bs=base('Forage'+role,(.15,.05,.07) if role=='Fruit' else (.22,.115,.038),.86 if role=='Fruit' else .72,0 if role=='Fruit' else .75)
    n=t.nodes.new('ShaderNodeVertexColor');n.layer_name='ForagePaint';t.links.new(n.outputs['Color'],bs.inputs['Base Color']);m.use_backface_culling=role!='Fruit';return m
