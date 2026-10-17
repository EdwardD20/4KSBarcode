//
//  Barcode/GraphicSheet.swift
//
//  Created by Ed Danley on 4/24/26.
//


import SwiftUI

// === SHEET that displays a PNG (graphic) with a title of (title) ===

// MARK: - UIKit container that manages layout & zoom correctly
final class ZoomContainerView: UIView, UIScrollViewDelegate {
    let scrollView = UIScrollView()
    let imageView  = UIImageView()
    var image: UIImage? { didSet { applyImage() } } // set by representable
    var hasAppliedInitialFit = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.maximumZoomScale = 4.0
        scrollView.minimumZoomScale = 1.0
        addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        // Double-tap to toggle fit ↔︎ 2× at tap point
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    } // init

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") } // init?

    override func layoutSubviews() {
        super.layoutSubviews()

        // Fill self
        scrollView.frame = bounds

        // If we have an image, size imageView to the *image’s intrinsic size* (points)
        if let img = imageView.image {
            imageView.frame = CGRect(origin: .zero, size: img.size)
            scrollView.contentSize = img.size

            // Compute aspect-fit scale for current scrollView size
            let fit = fitScale(container: scrollView.bounds.size, image: img.size)
            let newMin = max(fit, 0.01)

            // Only update if changed to avoid fighting user zoom
            if abs(scrollView.minimumZoomScale - newMin) > 0.0001 {
                scrollView.minimumZoomScale = newMin
                scrollView.maximumZoomScale = 4.0
                if !hasAppliedInitialFit {
                    scrollView.setZoomScale(newMin, animated: false)
                    hasAppliedInitialFit = true
                } else if scrollView.zoomScale < newMin {
                    scrollView.setZoomScale(newMin, animated: false)
                } // if
            } // if

            centerContent() // keep centered when smaller
        } // if
    } // layoutSubviews

    private func applyImage() {
        imageView.image = image
        hasAppliedInitialFit = false // recompute on next layout
        setNeedsLayout()
        layoutIfNeeded()
    } // applyImage

    private func fitScale(container: CGSize, image: CGSize) -> CGFloat {
        guard container.width > 0, container.height > 0, image.width > 0, image.height > 0 else { return 1.0 } // guard
        let w = container.width  / image.width
        let h = container.height / image.height
        return min(w, h) // aspect-fit
    } // fitScale

    private func centerContent() {
        let size = scrollView.bounds.size
        let content = scrollView.contentSize
        let hInset = max(0, (size.width  - content.width  * scrollView.zoomScale) * 0.5)
        let vInset = max(0, (size.height - content.height * scrollView.zoomScale) * 0.5)
        scrollView.contentInset = UIEdgeInsets(
            top: vInset,
            left: hInset,
            bottom: vInset,
            right: hInset
        )
    } // centerContent

    // MARK: - UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView // imageView
    } // viewForZooming

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent() // keep centered while pinching
    } // scrollViewDidZoom

    // MARK: - Double tap zoom
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let atFit = abs(scrollView.zoomScale - scrollView.minimumZoomScale) < 0.01
        let target = atFit ? min(scrollView.maximumZoomScale, scrollView.minimumZoomScale * 2.0)
                           : scrollView.minimumZoomScale

        let point = gesture.location(in: imageView)
        let size  = scrollView.bounds.size
        let w = size.width  / target
        let h = size.height / target
        let rect = CGRect(x: point.x - w / 2, y: point.y - h / 2, width: w, height: h)
        scrollView.zoom(to: rect, animated: true)
    } // handleDoubleTap
} // class ZoomContainerView

// MARK: - SwiftUI wrapper
struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ZoomContainerView {
        let v = ZoomContainerView()
        v.image = image
        return v
    } // makeUIView

    func updateUIView(_ uiView: ZoomContainerView, context: Context) {
        uiView.image = image // triggers re-fit if the image changes
    } // updateUIView
} // struct ZoomableImageView

// MARK: - Robust image lookup (main + SPM)
private func loadUIImage(named name: String) -> UIImage? {
    if let img = UIImage(named: name) { return img } // main
    if let img = UIImage(named: name, in: .main, compatibleWith: nil) { return img } // explicit main
    #if SWIFT_PACKAGE
    if let img = UIImage(named: name, in: Bundle.module, compatibleWith: nil) { return img } // SPM
    #endif
    return nil
} // loadUIImage

// MARK: - Your sheet
struct GraphicSheet: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    var graphic: String

    var body: some View {
        NavigationView {
            Group {
                if let uiImage = loadUIImage(named: graphic) {
                    ZoomableImageView(image: uiImage)
                        .ignoresSafeArea(edges: .bottom) // optional
                } else {
                    Text("Image not found: \(graphic)")
                        .foregroundColor(.secondary)
                        .padding()
                } // if
            } // Group
            .navigationTitle(Text(LocalizedStringKey(title)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedStringKey("close_button")) { dismiss() }
                } // ToolbarItem
            } // toolbar
        } // NavigationView
    } // body
} // struct GraphicSheet
