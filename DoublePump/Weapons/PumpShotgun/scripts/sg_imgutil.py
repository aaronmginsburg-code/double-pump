"""Image helpers shared by the bake scripts."""


def dilate(img, radius=24):
    """Pad islands outward (edge padding for mip-mapping) using alpha as coverage."""
    import numpy as np
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    filled = px[..., 3] > 0.5
    col = px[..., :3] * filled[..., None]
    for _ in range(radius):
        acc = np.zeros_like(col)
        cnt = np.zeros(filled.shape, dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            acc += np.roll(np.roll(col, dy, 0), dx, 1)
            cnt += np.roll(np.roll(filled, dy, 0), dx, 1)
        grow = (~filled) & (cnt > 0)
        col[grow] = acc[grow] / cnt[grow][:, None]
        filled = filled | grow
    if not filled.all():  # remaining gaps: mean colour
        col[~filled] = col[filled].mean(axis=0)
    px[..., :3] = col
    px[..., 3] = 1.0
    img.pixels.foreach_set(px.ravel())
    print(f"  {img.name}: coverage padded, {int((~(px[..., 3] > 0)).sum())} holes")
