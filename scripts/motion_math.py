"""Deterministic armature-space FK/analytic two-bone authoring helpers."""
import math
from mathutils import Vector, Matrix, Euler
import bpy
D = math.radians
TAU = math.tau

def smooth(t):
    t = max(0.0, min(1.0, t))
    return t*t*(3.0-2.0*t)

def curve(t, points):
    if t <= points[0][0]: return points[0][1]
    for (a, va), (b, vb) in zip(points, points[1:]):
        if t <= b:
            k = smooth((t-a)/(b-a))
            return va*(1-k) + vb*k
    return points[-1][1]

def trs(pos, degrees):
    return Matrix.Translation(Vector(pos)) @ Euler(tuple(D(x) for x in degrees), 'XYZ').to_matrix().to_4x4()

def fk(pb, name, angles):
    pb[name].rotation_quaternion = Euler(tuple(D(x) for x in angles), 'XYZ').to_quaternion()

def set_segment(pb, name, head, tail):
    bone = pb[name]
    rest = bone.bone.matrix_local.to_3x3()
    old_axis = bone.bone.tail_local - bone.bone.head_local
    rot = old_axis.rotation_difference(tail-head).to_matrix() @ rest
    mat = rot.to_4x4(); mat.translation = head
    bone.matrix = mat
    bpy.context.view_layer.update()

def two_bone(pb, upper, lower, target, pole):
    bpy.context.view_layer.update()
    h = pb[upper].head.copy()
    l1, l2 = pb[upper].bone.length, pb[lower].bone.length
    axis = target-h; raw_distance = axis.length
    distance = max(0.001, min(raw_distance, l1+l2-0.0001))
    axis.normalize()
    pole = Vector(pole)
    bend = pole-axis*pole.dot(axis)
    if bend.length < 0.0001: bend = Vector((1,0,0)).cross(axis)
    bend.normalize()
    along = (l1*l1-l2*l2+distance*distance)/(2.0*distance)
    height = math.sqrt(max(0.0, l1*l1-along*along))
    joint = h+axis*along+bend*height
    end = h+axis*distance
    set_segment(pb, upper, h, joint)
    set_segment(pb, lower, joint, end)
    return max(0.0, raw_distance-distance)

def foot_path(phase, period, speed, duty, lift):
    p = phase % 1.0
    span = speed*period*duty
    if p < duty:
        return span*0.5-speed*period*p, 0.097, 0.0, True
    t = (p-duty)/(1-duty)
    # Cubic Hermite return: velocity agrees with the contact branch at both ends.
    tangent = -speed*period*(1-duty)
    y = (2*t**3-3*t*t+1)*(-span/2) + (t**3-2*t*t+t)*tangent
    y += (-2*t**3+3*t*t)*(span/2)+(t**3-t*t)*tangent
    return y, 0.097+lift*math.sin(math.pi*t)**2, 12*math.sin(TAU*t), False

def fcurves(action):
    if hasattr(action, 'fcurves'): return list(action.fcurves)
    return [fc for la in action.layers for st in la.strips for cb in st.channelbags for fc in cb.fcurves]
