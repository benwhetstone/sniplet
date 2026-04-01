import CoreGraphics
import Testing

@Test
func cropIntersectionReturnsExpectedRect() {
    let screenFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
    let selection = CGRect(x: 10, y: 20, width: 30, height: 40)
    let imageHeight: CGFloat = 200
    let imageWidth: CGFloat = 200

    let scaleX = imageWidth / screenFrame.width
    let scaleY = imageHeight / screenFrame.height
    let localMinX = selection.minX - screenFrame.minX
    let localMaxY = selection.maxY - screenFrame.minY

    let cropRect = CGRect(
        x: localMinX * scaleX,
        y: imageHeight - (localMaxY * scaleY),
        width: selection.width * scaleX,
        height: selection.height * scaleY
    ).integral

    #expect(cropRect == CGRect(x: 20, y: 80, width: 60, height: 80))
}
