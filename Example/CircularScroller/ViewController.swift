//
//  ViewController.swift
//  InfiniteScroll
//
//  Created by daniele on 24/10/2019.
//  Copyright © 2019 daniele. All rights reserved.
//

import UIKit

class ViewController: UIViewController, CircularScrollViewDataSource {
    func numPagesIn(scrollView: CircularScrollView) -> Int {
        return 3
    }
    
    func viewFor(page: Int, within scrollView: CircularScrollView) -> UIView {
        return data[page]
    }
    
   
    func viewPage(_ int: Int, view: UILabel) {
        view.text = "Page: \(int)"
    }
    
    var data: [UILabel] = [
        UILabel(),
        UILabel(),
        UILabel(),
]
    

    @IBOutlet public var infinite: CircularScrollView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        data[0].text = "1"
        data[0].font = UIFont.boldSystemFont(ofSize: 100)
        data[0].textAlignment = .center
        data[0].backgroundColor = .yellow
        
        data[1].text = "2"
        data[1].font = UIFont.boldSystemFont(ofSize: 100)
        data[1].textAlignment = .center
        data[1].backgroundColor = .orange
        
        data[2].text = "3"
        data[2].font = UIFont.boldSystemFont(ofSize: 100)
        data[2].textAlignment = .center
        data[2].backgroundColor = .red


        infinite?.scrollViewDataSource = self
        infinite?.moveTo(page: 0)
    }


}

