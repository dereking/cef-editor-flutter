export interface PastedImageSizeInput {
  naturalWidth: number;
  naturalHeight: number;
  devicePixelRatio: number;
  maxWidth: number;
}

export interface PastedImageSize {
  width: number;
  height: number;
}

export function calculatePastedImageSize({
  naturalWidth,
  naturalHeight,
  devicePixelRatio,
  maxWidth,
}: PastedImageSizeInput): PastedImageSize | null {
  if (
    ![naturalWidth, naturalHeight, devicePixelRatio, maxWidth].every(
      (value) => Number.isFinite(value) && value > 0,
    )
  ) {
    return null;
  }

  const logicalWidth = naturalWidth / devicePixelRatio;
  const logicalHeight = naturalHeight / devicePixelRatio;
  const scale = Math.min(1, maxWidth / logicalWidth);
  return {
    width: logicalWidth * scale,
    height: logicalHeight * scale,
  };
}
