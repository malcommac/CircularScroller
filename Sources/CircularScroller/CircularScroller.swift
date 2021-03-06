/*
 * CircularScroller
 * Efficient and Lightweight endless UIScrollView implementation in Swift
 *
 * Created by:    Daniele Margutti
 * Email:        hello@danielemargutti.com
 * Web:            http://www.danielemargutti.com
 * Twitter:        @danielemargutti
 *
 * Copyright © 2019 Daniele Margutti
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */


import UIKit

// MARK: - CircularScrollerDataSource

public protocol CircularScrollerDataSource: class {
    
    /// Number of pages of the scrollview.
    ///
    /// - Parameter scrollView: source scrollview.
    func numberOfPages(scrollView: CircularScroller) -> Int
    
    /// Return the view at given page index.
    ///
    /// - Parameter page: index of page to render.
    /// - Parameter destinationHolder: position into the holder view for this page (previous view, current view or next view)
    /// - Parameter scrollView: source scrollview.
    func viewForPage(atIndex page: Int, destinationHolder: CircularScroller.ViewHolderType, scrollView: CircularScroller) -> UIView
    
}

// MARK: - CircularScrollerDelegate

public protocol CircularScrollerDelegate: class {
    
    /// Circular scroll view did scroll to specified location.
    ///
    /// - Parameter location: location of the scroll.
    /// - Parameter scrollView: source scrollview.
    func circularScrollerDidScrollTo(location: CGPoint, scrollView: CircularScroller)
    
    /// Circular scroll view did scroll to specified page.
    ///
    /// - Parameter page: page of the scroll.
    /// - Parameter scrollView: source scrollview.
    func circularScrollerDidScrollTo(page: Int, scrollView: CircularScroller)
    
    /// This allows you to set the opportunity to preload stuff for a specific page, ie. images.
    ///
    /// - Parameters:
    ///   - pages: page indexes you can start to prefetch.
    ///   - scrollView: source scrollview.
    func circularScrollerPrefetchItemsForPages(_ pages: Set<Int>, scrollView: CircularScroller)
    
    /// Called when user tap on a page item.
    ///
    /// - Parameters:
    ///   - page: page index.
    ///   - scrollView: source scrollview.
    func circularScrollerDidTapOn(page: Int, scrollView: CircularScroller)

}

// MARK: - CircularScrollView

public class CircularScroller: UIView, UIScrollViewDelegate {
    
    // MARK: - Public Properties
    
    /// When a single page is rendered scroll can be disabled.
    /// By default is set to `false`.
    public var disableScrollOnSinglePage = false
        
    /// Current page index.
    public private(set) var currentPageIdx = 0
    
    /// Circular scorll view delegate.
    public weak var delegate: CircularScrollerDelegate?
        
    /// Data source.
    public weak var dataSource: CircularScrollerDataSource? {
        didSet {
            if dataSource != nil {
                loadPageAtIndex(_ : 0)
                recenterScrollOffset()
            }
        }
    }
    
    // MARK: - Private Properties
    
    /// ScrollView with the data.
    /// 
    /// NOTE:
    /// We have used a scrollview instead of ineriths the CircularScrollView from UIScrollView
    /// because this allows us to specify the height (height of the scrollview's subview to the height
    /// of self) otherwise autolayout tends to compress the size of the entire control to the size of its content.
    private var scrollView = UIScrollView()

    /// The number of page view holders.
    private static let CacheHoldersCount = 3
    
    private lazy var centerPageIndex: Int = {
       return Int(round( Double(CircularScroller.CacheHoldersCount) / Double(2)))
    }()
    
    /// Contains the holder views where the page's view were added.
    /// Holders are 3 (previous page, current page, next page).
    private var holderViews = [UIView]()
    
    /// The superview where holders are added. This is the only subview of the scrollview
    /// and define it's length as contentSize.
    private var containerView = UIView()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        initializeUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        initializeUI()
    }
    
    // MARK: - Public Functions
    
    public func setCurrentPageIndex(_ newIndex: Int) {
        guard newIndex != currentPageIdx else {
            return
        }
        
        loadPageAtIndex(_ : newIndex)
        recenterScrollOffset()
    }
    
    /// Reload data with the current page index.
    /// If current page index does not exists anymore then starts from 0.
    public func reloadData() {
        guard let numberOfPages = dataSource?.numberOfPages(scrollView: self), currentPageIdx < numberOfPages else {
            currentPageIdx = 0
            reloadData()
            return
        }
        
        loadPageAtIndex(currentPageIdx)
    }
    
    // MARK: - UIScrollView Events
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let delta = determineNextPageDeltaFromScroll() else {
            return
        }
        
        // Load next page
        let nextPageToLoad = nextPageIndexFrom(currentPageIdx, delta: delta)
        currentPageIdx = nextPageToLoad
        loadPageAtIndex(currentPageIdx)
        recenterScrollOffset()

        delegate?.circularScrollerDidScrollTo(location: scrollView.contentOffset, scrollView: self)
    }
    
    // MARK: - Private Functions (Layout)
    
    private func initializeUI() {
        scrollView.delegate = self
        
        scrollView.clipsToBounds = true
        scrollView.isPagingEnabled = true
        scrollView.bounces = true
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapOnCurrentPage))
        scrollView.addGestureRecognizer(tapGesture)
    }

    @objc func didTapOnCurrentPage() {
        delegate?.circularScrollerDidTapOn(page: currentPageIdx, scrollView: self)
    }
    
    public override func didMoveToSuperview() {
        if superview != nil {
            // Setup the scroll view.
            addSubview(scrollView)
            scrollView.constraintToSuperview()

            setupMainContainer()
        }
    }
    
    /// Setup the main container which hold the three page cache.
    private func setupMainContainer() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        // containerView.backgroundColor = .yellow

        let left = scrollView.leftAnchor.constraint(equalTo: containerView.leftAnchor)
        let right = scrollView.rightAnchor.constraint(equalTo: containerView.rightAnchor)
        let top = scrollView.topAnchor.constraint(equalTo: containerView.topAnchor)
        let bottom = scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        let width = containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, multiplier: CGFloat(CircularScroller.CacheHoldersCount))
        let height = containerView.heightAnchor.constraint(equalTo: self.heightAnchor)

        scrollView.addSubview(containerView)
        scrollView.addConstraints([left, right, top, bottom, width])
        
        self.addConstraint(height)
        
        setupCachePagesInContainer()
    }
    
    /// Place the three cache view pages (previous, current and next page view).
    /// Each of these view contains the real pages asked to the datasource.
    private func setupCachePagesInContainer() {
        var previousView = containerView
        
        for idx in 0..<CircularScroller.CacheHoldersCount {
            let cachePageView = UIView()
            cachePageView.translatesAutoresizingMaskIntoConstraints = false
            
            // cachePageView.backgroundColor = UIColor.randomColor()

            containerView.addSubview(cachePageView)
            cachePageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 0).isActive = true
            cachePageView.leadingAnchor.constraint(equalTo: (idx == 0 ? containerView.leadingAnchor : previousView.trailingAnchor)).isActive = true
            cachePageView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: CGFloat(1)/CGFloat(CircularScroller.CacheHoldersCount)).isActive = true
            // cachePageView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 1).isActive = true
            // cachePageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 0).isActive = true
            let height = cachePageView.heightAnchor.constraint(equalTo: self.heightAnchor)
            self.addConstraint(height)

            holderViews.append(cachePageView)
            previousView = cachePageView
        }
    }
        
    /// Determine the next page index to cache and load on scroll.
    private func determineNextPageDeltaFromScroll() -> Int? {
        let scrollToNextPageOffset = CGFloat(centerPageIndex) * bounds.size.width
        let scrollToPrevPageOffset = CGFloat(centerPageIndex - 2) * bounds.size.width
        
        if scrollView.contentOffset.x >= scrollToNextPageOffset {
            return 1
        } else if scrollView.contentOffset.x <= scrollToPrevPageOffset {
            return -1
        }
        
        return nil
    }
    
    // MARK: Private Methods
    
    /// Load a new current page.
    ///
    /// - Parameter pageNum: index of the page to load.
    private func loadPageAtIndex(_  newIndex: Int) {
        guard let dataSource = dataSource, dataSource.numberOfPages(scrollView: self) > 0 else {
            debugPrint("No data source is set or zero items, ignoring loadPageAtIndex call.")
            return
        }
        
        currentPageIdx = newIndex
        
        // Disable scroll for on epage items
        scrollView.isScrollEnabled = (disableScrollOnSinglePage && dataSource.numberOfPages(scrollView: self) == 1 ? false : true)

        let centerIdx = (centerPageIndex - 1)
        for cachePageIdx in 0..<CircularScroller.CacheHoldersCount {
            let incrementValue = (cachePageIdx - centerIdx)
            let realPageIdx = nextPageIndexFrom(newIndex, delta: incrementValue)
                  
            loadContentOfPageAtIndex(realPageIdx, intoCacheView: cachePageIdx)
        }
        
        // Ask for prefetching of the content.
        askForPrefetchFromPageAtIndex(newIndex)
        
        delegate?.circularScrollerDidScrollTo(page: newIndex, scrollView: self)
    }
    
    /// Ask to the delegate a set of pages to prefetch.
    ///
    /// - Parameter currentPage: current page.
    private func askForPrefetchFromPageAtIndex(_ currentPage: Int) {
        var pageIndexesToPrefetch = Set<Int>()
        
        // Add pages to prefetch
        let pageRangeToIncludeFromCurrent = 3
        for idx in -pageRangeToIncludeFromCurrent..<abs(pageRangeToIncludeFromCurrent) {
            if idx == currentPage {
                return
            }
            let nextPage = nextPageIndexFrom(currentPage, delta: idx)
            pageIndexesToPrefetch.insert(nextPage)
        }
                
        delegate?.circularScrollerPrefetchItemsForPages(pageIndexesToPrefetch, scrollView: self)
    }
    
    /// Place the view of the given page index into one of the cached views (prev, current or next page).
    ///
    /// - Parameters:
    ///   - idx: index of the page to load.
    ///   - cachedIdx: destination cached page view.
    private func loadContentOfPageAtIndex(_ idx: Int, intoCacheView cachedIdx: Int) {
        let location = ViewHolderType(rawValue: cachedIdx)!
        let contentView = dataSource!.viewForPage(atIndex: idx, destinationHolder: location, scrollView: self)
        let destinationView = holderViews[cachedIdx]
        
        destinationView.subviews.forEach {
            $0.removeFromSuperview()
        }
        
        destinationView.addSubview(contentView)
        contentView.constraintToSuperview()
    }
    
    /// Return the next real page index from a current start page.
    ///
    /// - Parameters:
    ///   - page: current page index.
    ///   - delta: delta increment, may be positive (1 for next page) or negative (-1 for previous page).
    private func nextPageIndexFrom(_ page: Int, delta: Int) -> Int {
        let countElements = dataSource!.numberOfPages(scrollView: self)
        let nextIndex = Int.circularIndexFrom(page, delta: delta, count: countElements)!
        return nextIndex
    }
    
    /// Recenter the scroll offset. This method is usually called after you load a page as current page
    /// in order to recenter the current page at index 1 (center view).
    private func recenterScrollOffset() {
        self.layoutIfNeeded() // update a frame based on constraints, otherwise we'll get zero
        let centerOffsetX = CGFloat(centerPageIndex - 1) * bounds.size.width
        // NOTE:
        // Instead of contentOffset we set the bounds directly in order to avoid triggering didScroll delegate
        // method which also trigger some other stuff we don't really want to be triggered!
        scrollView.bounds.origin = CGPoint(x: centerOffsetX, y: 0)
    }
    
}

public extension CircularScroller {
    
    enum ViewHolderType: Int {
        case previousPage = 0
        case currentPage
        case nextPage
    }
    
}

// MARK: - Extension Int (Circular Array)

extension Int {
    
    /// Return the next index in a circular array starting from a given index and moving by delta.
    ///
    /// - Parameters:
    ///   - current: current index of the array.
    ///   - delta: delta increment, may be positive or negative.
    ///   - count: number of items in array
    public static func circularIndexFrom(_ current: Int, delta: Int, count: Int) -> Int? {
        guard current >= 0 && current < count else {
            debugPrint("Failed to get correct circular index; given start position is out of bounds \(current), total is \(count)")
            return nil
        }
        
        let nextIndex = (current + delta) % count
        return (nextIndex >= 0 ? nextIndex : (count + nextIndex))
    }
    
}

internal extension UIView {
    
    func constraintToSuperview() {
        guard let superview = self.superview else {
            assert(false, "Error! `superview` was nil – call `addSubview(_ view: UIView)` before calling `\(#function)` to fix this.")
            return
        }
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview.topAnchor, constant: 0),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: 0),
            leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: 0),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: 0)
        ])
    }
    
}
