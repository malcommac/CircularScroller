//
//  CircularScrollView.swift
//  CircularScrollView
//
//  Created by daniele on 24/10/2019.
//  Copyright © 2019 daniele. All rights reserved.
//

import UIKit

protocol CircularScrollViewDataSource {
    func numPagesIn(scrollView:CircularScrollView) -> Int
    func viewFor(page:Int, within scrollView:CircularScrollView) -> UIView
}

protocol CircularScrollViewDelegate {
    func scrollViewDidScrollTo(location:CGPoint, within scrollView:CircularScrollView)
    func scrollViewDidScrollTo(page:Int, within scrollView:CircularScrollView)
}


public class CircularScrollView: UIScrollView, UIScrollViewDelegate {
    
    enum ScrollDirection {
        case forward
        case backward
        case none
    }
    
    internal var pagesView = [UIView]()// [UIView(), UIView(), UIView()]
    internal var currentPage = 0

    var scrollViewDelegate: CircularScrollViewDelegate? = nil

    var scrollViewDataSource: CircularScrollViewDataSource? = nil {
        didSet {
            // initialize views when setting new data source
            
            if scrollViewDataSource != nil {
                currentPage = 0
                loadPageAtIndex(_ : currentPage)
                recenterScrollOffset()
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        initializeUI()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        initializeUI()
    }
    
    public func moveTo(page:Int) {
        currentPage = page
        loadPageAtIndex(_ : currentPage)
        recenterScrollOffset()
    }
    
    private func initializeUI() {
        clipsToBounds = true
        isPagingEnabled = true
        bounces = false
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        delegate = self
        setUpSubviews() //from layout extension
    }

    internal func setUpSubviews() {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let leftView = UIView()
        leftView.translatesAutoresizingMaskIntoConstraints = false
        
        let  centerView = UIView()
        centerView.translatesAutoresizingMaskIntoConstraints = false
        
         let rightView = UIView()
        rightView.translatesAutoresizingMaskIntoConstraints = false
        
        self.addSubview(containerView)
        containerView.addSubview(leftView)
        containerView.addSubview(centerView)
        containerView.addSubview(rightView)
        
        // container view constraints
        let container_left = self.leftAnchor.constraint(equalTo: containerView.leftAnchor)
        let container_right = self.rightAnchor.constraint(equalTo: containerView.rightAnchor)
        let container_top = self.topAnchor.constraint(equalTo: containerView.topAnchor)
        let container_bottom = self.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        let container_height = self.heightAnchor.constraint(equalTo: containerView.heightAnchor)
        let container_width = self.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: (1/3))
        
        self.addConstraints([container_left, container_right, container_top,
                             container_bottom, container_height, container_width])
        
        
        // left View constraints
        let left_left = containerView.leftAnchor.constraint(equalTo: leftView.leftAnchor)
        let left_right = centerView.leftAnchor.constraint(equalTo: leftView.rightAnchor)
        let left_top = containerView.topAnchor.constraint(equalTo: leftView.topAnchor)
        let left_bottom = containerView.bottomAnchor.constraint(equalTo: leftView.bottomAnchor)
        
        containerView.addConstraints([left_left, left_right, left_top, left_bottom])
        
        // center view constraints
        let center_left = leftView.rightAnchor.constraint(equalTo: centerView.leftAnchor)
        let center_right = rightView.leftAnchor.constraint(equalTo: centerView.rightAnchor)
        let center_top = containerView.topAnchor.constraint(equalTo: centerView.topAnchor)
        let center_bottom = containerView.bottomAnchor.constraint(equalTo: centerView.bottomAnchor)
        
        containerView.addConstraints([center_left, center_right, center_top, center_bottom])
        
        // right view constraints
        let right_left = centerView.rightAnchor.constraint(equalTo: rightView.leftAnchor)
        let right_right = containerView.rightAnchor.constraint(equalTo: rightView.rightAnchor)
        let right_top = containerView.topAnchor.constraint(equalTo: rightView.topAnchor)
        let right_bottom = containerView.bottomAnchor.constraint(equalTo: rightView.bottomAnchor)
        
        containerView.addConstraints([right_left, right_right, right_top, right_bottom])
        
        
        // equal widths
        let right_width = rightView.widthAnchor.constraint(equalTo: centerView.widthAnchor)
        let left_width = leftView.widthAnchor.constraint(equalTo: centerView.widthAnchor)
        
        containerView.addConstraints([right_width, left_width])
        
        pagesView = [leftView,centerView,rightView]
        
    }
    
    private func recenterScrollOffset() {
        contentOffset = CGPoint(x: bounds.size.width, y: 0)
    }
    
    private func getScrollDirection() -> ScrollDirection {
        if contentOffset.x == 0 { return .backward }
        if contentOffset.x == frame.width { return .none }
        return .forward
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let scrollDirection = getScrollDirection()
        currentPage = indexOfNextPageAtDirection(scrollDirection, from: currentPage)
        
        loadPageAtIndex(currentPage)
        recenterScrollOffset()
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        //calculate offset as if this was a regular UIScrollView and send to delegate
        if let dataSource = scrollViewDataSource {
            let numPages = dataSource.numPagesIn(scrollView: self)
            let fullWidth = frame.width * CGFloat(numPages)
            
            let offset = (self.contentOffset.x - frame.width) + (frame.width * CGFloat(currentPage))
            var finalX = offset
            
            if offset < 0 {
                finalX = fullWidth - offset
            } else if offset > fullWidth {
                finalX = offset - fullWidth
            }
            
            scrollViewDelegate?.scrollViewDidScrollTo(location: CGPoint(x: finalX, y: 0), within: self)

            if numPages == 2 && contentOffset.x <  frame.width {
                let leftIndex = indexOfNextPageAtDirection(.backward, from: currentPage)
                let leftViewContent = dataSource.viewFor(page: leftIndex, within:self)
                updateContentsOf(page: pagesView[0], with: leftViewContent)
            }

        }
        
        
    }
    
    internal func indexOfNextPageAtDirection(_ scrollDirection: ScrollDirection, from page: Int) -> Int {
        guard let scrollViewDataSource = scrollViewDataSource else {
            return 0
        }

        let numPages = scrollViewDataSource.numPagesIn(scrollView: self)
        switch scrollDirection {
            case .forward:
                return (page + 1) % numPages

            case .backward:
                return page > 0 ? page - 1 : numPages - 1

            case .none:
                return page
            
        }
    }
    
    internal func loadPageAtIndex(_  pageNum:Int) {
        
        scrollViewDelegate?.scrollViewDidScrollTo(page: pageNum, within: self)
        
        if let dataSource = scrollViewDataSource {
            let leftIndex = indexOfNextPageAtDirection(.backward, from: pageNum)
            let leftViewContent = dataSource.viewFor(page: leftIndex, within:self)
            
            let rightIndex = indexOfNextPageAtDirection(.forward, from: pageNum)
            let rightViewContent = dataSource.viewFor(page: rightIndex, within:self)
            
            let centerViewContent = dataSource.viewFor(page: pageNum, within:self)
            
            updateContentsOf(page: pagesView[0], with: leftViewContent)
            updateContentsOf(page: pagesView[2], with: rightViewContent)
            updateContentsOf(page: pagesView[1], with: centerViewContent)
        }
    }
    
    internal func updateContentsOf(page:UIView, with subview:UIView) {
        for subview in page.subviews {
            subview.removeFromSuperview()
        }
        
        subview.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(subview)
        
        let top = subview.topAnchor.constraint(equalTo: page.topAnchor)
        let bottom = subview.bottomAnchor.constraint(equalTo: page.bottomAnchor)
        let left = subview.leftAnchor.constraint(equalTo: page.leftAnchor)
        let right = subview.rightAnchor.constraint(equalTo: page.rightAnchor)
        
        page.addConstraints([top, bottom, left, right])
    }
    
}


extension UIColor {
    
    static func random(hue: CGFloat = CGFloat.random(in: 0...1),
                       saturation: CGFloat = CGFloat.random(in: 0.5...1), // from 0.5 to 1.0 to stay away from white
        brightness: CGFloat = CGFloat.random(in: 0.5...1), // from 0.5 to 1.0 to stay away from black
        alpha: CGFloat = 1) -> UIColor {
        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }
}
