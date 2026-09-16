from pathlib import Path
from PIL import Image
import json
import argparse
parser=argparse.ArgumentParser(description='Compare the 48 synthetic SFML renderer snapshots, reporting exact-boundary differences separately.')
parser.add_argument('--baseline',type=Path,required=True)
parser.add_argument('--candidate',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
results=[]
for f in sorted(args.baseline.glob('*.png')):
    kind,scale,mode,background=f.stem.split('-')
    a=Image.open(f).convert('RGBA');b=Image.open(args.candidate/f.name).convert('RGBA')
    assert a.size==b.size==(64,64)
    changed=0;maxdiff=0;off_boundary=0;off_boundary_max=0
    for y in range(64):
        for x in range(64):
            diff=max(abs(i-j) for i,j in zip(a.getpixel((x,y)),b.getpixel((x,y))))
            if not diff:continue
            changed+=1;maxdiff=max(maxdiff,diff)
            # Original fractional sprite occupies [4,54)x[5,49). Pixel centers that
            # transform to exact integer texel coordinates can round either way.
            boundary=False
            if scale=='0' and 4<=x<54 and 5<=y<49:
                u=(x+0.5-4)/6.25;v=(y+0.5-5)/5.5
                boundary=abs(u-round(u))<1e-8 or abs(v-round(v))<1e-8
            if not boundary:off_boundary+=1;off_boundary_max=max(off_boundary_max,diff)
    results.append({'file':f.name,'changed_pixels':changed,'max_channel_delta':maxdiff,'off_texel_boundary_pixels':off_boundary,'off_texel_boundary_max_delta':off_boundary_max})
assert len(results)==48,len(results)
args.output.write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps({'images':48,'exact_images':sum(r['changed_pixels']==0 for r in results),'integer_scale_exact':sum(r['changed_pixels']==0 for r in results if r['file'].split('-')[1]=='1'),'total_off_boundary_pixels':sum(r['off_texel_boundary_pixels'] for r in results),'max_off_boundary_delta':max(r['off_texel_boundary_max_delta'] for r in results)},indent=2))
