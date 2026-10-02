from std.collections import List
from std.testing import assert_true, assert_equal, assert_almost_equal
from moxi.constraint_layout import ConstraintRegion, LinearConstraint, coordinate, PARENT_WIDTH, AT_LEAST
from moxi.geometry import Size


def model(width: Float64 = 80) raises -> List[LinearConstraint]:
    return [LinearConstraint([coordinate(1,0)],[Float64(1)],-10),
            LinearConstraint([coordinate(1,1)],[Float64(1)],-8),
            LinearConstraint([coordinate(1,2)],[Float64(1)],-width,AT_LEAST),
            LinearConstraint([coordinate(1,2),PARENT_WIDTH],[Float64(1),-1],20),
            LinearConstraint([coordinate(1,3)],[Float64(1)],-30)]


def main() raises:
    var region = ConstraintRegion()
    region.model([1],model())
    var first = region.stage(Size(200,60))
    region.commit(first)
    assert_almost_equal(region.bounds(1).width,Float32(180))
    var builds = region.solver_builds
    region.model([1],model())
    var same = region.stage(Size(200,60))
    region.commit(same)
    assert_equal(region.solver_builds,builds)
    var rejected = False
    try:
        _ = region.stage(Size(60,60))
    except:
        rejected = True
    assert_true(rejected)
    assert_almost_equal(region.bounds(1).width,Float32(180))
    # Staging without committing leaves the previous solved geometry intact.
    var pending = region.stage(Size(300,60))
    assert_almost_equal(region.bounds(1).width,Float32(180))
    region.model([1],model(90))
    rejected = False
    try:
        region.commit(pending)
    except:
        rejected = True
    assert_true(rejected)
    var weighted = model(90)
    weighted.append(LinearConstraint([coordinate(1,2)],[Float64(1)],-100,strength=1))
    region.model([1],weighted)
    pending = region.stage(Size(300,60))
    assert_almost_equal(pending.residuals[len(pending.residuals)-1],Float64(180))
    region.commit(pending)
    for i in range(1000):
        pending = region.stage(Size(Float32(200+i%5),60))
        region.commit(pending)
    assert_true(region.solver_builds<=1005)
    print("Constraint layout contracts passed (1,000 staged rebuilds)")
