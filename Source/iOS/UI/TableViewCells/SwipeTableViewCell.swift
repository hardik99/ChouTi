//
//  SwipeTableViewCell.swift
//  iOSScoreESports
//
//  Created by Honghao Zhang on 2016-08-04.
//  Copyright © 2016 theScore Inc. All rights reserved.
//

import UIKit

/**
 SwipeTableVewCell Delegate.
 Delegate methods allow the delegate to react to cell swipe offset changes.
 */
public protocol SwipeTableViewCellDelegate: class {
    /**
     SwipeTableViewCell swiped to new offset.
     
     - parameter cell:      SwipeTableViewCell self.
     - parameter newOffset: New offset swiped. Negative value means right side expanded.
     */
    func swipeTableViewCell(cell: SwipeTableViewCell, didSwipeToOffset newOffset: CGFloat)
}

/**
 UITableViewCell with swipe actions
 This is a cell which can swipe to show accessory view. Just like UIKit swipe to delete view.
 You need to configue `rightSwipeAccessoryView` to a view with constraint based layout (Require size constrained).
 */
public class SwipeTableViewCell: UITableViewCell {
    
    // Swipeable content view, normally you should add subviews on this view
    public final let swipeableContentView = UIView()
    
    // MARK: - Right Accessory View
    /// Accessory view to show when swipe from right to left ( <--o )
    /// Note: This view requires constraint based layout. Make sure this view has size constrained.
    public var rightSwipeAccessoryView: UIView? {
        didSet {
            guard let rightSwipeAccessoryView = rightSwipeAccessoryView else { return }
            rightSwipeAccessoryView.translatesAutoresizingMaskIntoConstraints = false
            contentView.insertSubview(rightSwipeAccessoryView, belowSubview: swipeableContentView)
            
            NSLayoutConstraint(item: rightSwipeAccessoryView, attribute: .Trailing, relatedBy: .Equal, toItem: contentView, attribute: .Trailing, multiplier: 1.0, constant: 0.0).active = true
            NSLayoutConstraint(item: rightSwipeAccessoryView, attribute: .CenterY, relatedBy: .Equal, toItem: contentView, attribute: .CenterY, multiplier: 1.0, constant: 0.0).active = true
        }
    }
    
    /// Checking whether cell is expanded on the right.
    public private(set) var rightSwipeExpanded: Bool = false
    
    /// Expandable width for swiping on right
    private final var rightSwipeExpandableWidth: CGFloat { get { return rightSwipeAccessoryView?.bounds.width ?? 0.0 } }
    private final var rightSwipeEnabled: Bool { return rightSwipeExpandableWidth > 0.0 }
    
    // MARK: - Delegate
    /// Swipe table view cell delegate.
    public weak var swipeTableViewCellDelegate: SwipeTableViewCellDelegate?
    
    // MARK: - Private
    private final var swipeableContentViewCenterXConstraint: NSLayoutConstraint!
    private final var panStartPoint: CGPoint = .zero
    private final var centerXConstraintStartConstant: CGFloat = 0.0
    
    /// Flag for whether this cell is observing a tableView
    private final var isObservingTableView: Bool = false
    
    // MARK: - Gesture Recognizers
    private final lazy var panRecognizer: UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(SwipeTableViewCell.panSwipeableContentView(_:)))
    private final lazy var tapRecognizer: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SwipeTableViewCell.tapContentView(_:)))
    // This is a so called immediate touch gesture recognizer (no delay, triggers faster than tap gesture recognizer). Set `minimumPressDuration = 0`.
    private final let immediateTouchRecognizer = UILongPressGestureRecognizer()
    
    // MARK: - Settings when cell's tableView is embedded in a scrollView
    /// Unscrollable screen edge width. Default value is 40
    /// Pans on this width of screen edges won't expand cell
    public final var unscrollableScreenEdgeWidth: CGFloat = 40
    
    /// Horizontal velocity threshold when scrolls cell, if scrolling velocity is greater than this threshold, cell won't expand.
    /// Default value is 750.0
    public final var cellScrollsVelocityThreshold: CGFloat = 750.0
    
    // MARK: - Methods
    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private final func commonInit() {
        // Remove default selection style (long press on cell can select it)
        selectionStyle = .None
        
        swipeableContentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(swipeableContentView)
        swipeableContentView.backgroundColor = UIColor.whiteColor()
        
        // Gestures
        // Pan on cells
        swipeableContentView.addGestureRecognizer(panRecognizer)
        panRecognizer.delegate = self
        
        // Tap on cells
        contentView.addGestureRecognizer(tapRecognizer)
        tapRecognizer.delegate = self
        
        // Touch on cells
        contentView.addGestureRecognizer(immediateTouchRecognizer)
        immediateTouchRecognizer.minimumPressDuration = 0.0
        immediateTouchRecognizer.delegate = self
        panRecognizer.dependsOn(immediateTouchRecognizer)
        
        setupConstraints()
    }
    
    private final func setupConstraints() {
        var constraints: [NSLayoutConstraint] = []
        
        // Swipeable content view
        swipeableContentViewCenterXConstraint = NSLayoutConstraint(item: swipeableContentView,
                                                                   attribute: .CenterX,
                                                                   relatedBy: .Equal,
                                                                   toItem: contentView,
                                                                   attribute: .CenterX,
                                                                   multiplier: 1.0,
                                                                   constant: 0.0)
        
        constraints += [
            NSLayoutConstraint(item: swipeableContentView, attribute: .Height, relatedBy: .Equal, toItem: contentView, attribute: .Height, multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(item: swipeableContentView, attribute: .Width, relatedBy: .Equal, toItem: contentView, attribute: .Width, multiplier: 1.0, constant: 0.0),
            swipeableContentViewCenterXConstraint,
            NSLayoutConstraint(item: swipeableContentView, attribute: .CenterY, relatedBy: .Equal, toItem: contentView, attribute: .CenterY, multiplier: 1.0, constant: 0.0)
        ]
        
        // This resolves `UITableViewCellContentView`'s NSAutoresizingMaskLayoutConstraint or `UIView-Encapsulated-Layout-Height` warnings when setting `contentView` height using constraints.
        // http://stackoverflow.com/a/38086932/3164091
        contentView.autoresizingMask = [.FlexibleHeight]
        
        // set 44.0 default cell height
        let cellHeightConstraint = NSLayoutConstraint(item: contentView, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 0.0, constant: 44.0)
        cellHeightConstraint.priority = 250
        constraints += [cellHeightConstraint]
        
        NSLayoutConstraint.activateConstraints(constraints)
    }
    
    deinit {
        removeTableViewContentOffsetObservation()
    }
}

// MARK: - Expanding/Collapse
extension SwipeTableViewCell {
    /**
     Expand right side to show right accessory view.
     
     - parameter animated: Whether it's should be animated.
     */
    public func expandRightSide(animated animated: Bool) {
        setExpandOffset(rightSwipeExpandableWidth, animated: animated)
    }
    
    /**
     Collapse self.
     
     - parameter animated: Whether it's should be animated.
     */
    public func collapse(animated animated: Bool) {
        setExpandOffset(0, animated: animated)
        
        // Any cell collapsing (cell reuse, cell state transition, cell didMoveToWindow) should collapse all other cells
        collapseAllOtherCells()
    }
    
    /**
     Update swipeable content view with expand offset. (Offset is positive if expand on right side)
     
     - parameter offset:   New offset to set.
     - parameter animated: Whether it's should be animated.
     */
    private final func setExpandOffset(offset: CGFloat, animated: Bool) {
        // Avoid duplicated calls, avoid unnecessary `layoutIfNeeded` calls
        guard swipeableContentViewCenterXConstraint.constant != -offset else { return }
		
        swipeableContentViewCenterXConstraint.constant = -offset
        swipeTableViewCellDelegate?.swipeTableViewCell(self, didSwipeToOffset: -offset)
        
        if animated {
            UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 1.0, options: [.CurveEaseInOut, .BeginFromCurrentState], animations: {
                self.swipeableContentView.superview?.layoutIfNeeded()
            }, completion: { _ in
                self.rightSwipeExpanded = (offset != 0.0)
            })
        } else {
            swipeableContentView.superview?.layoutIfNeeded()
            rightSwipeExpanded = (offset != 0.0)
        }
    }
    
    /**
     Collapses all other cells in current tableView
     */
    private final func collapseAllOtherCells() {
        tableView?.visibleCells.forEach {
            guard let swipeCell = $0 as? SwipeTableViewCell where swipeCell !== self else { return }
            swipeCell.setExpandOffset(0, animated: true)
        }
    }
}

// MARK: - Gesture Recognizer Actions
extension SwipeTableViewCell {
    private dynamic func panSwipeableContentView(panRecognizer: UIPanGestureRecognizer) {
        let currentPoint = panRecognizer.translationInView(swipeableContentView)
        let deltaX = { currentPoint.x - panStartPoint.x }()
        
        switch panRecognizer.state {
        case .Began:
            panStartPoint = currentPoint
            centerXConstraintStartConstant = swipeableContentViewCenterXConstraint.constant
            
        case .Changed:
            let newConstant = centerXConstraintStartConstant + deltaX
            // Disable swipe cell to right
            if newConstant > 0 {
                setExpandOffset(0.0, animated: false)
            }
            else if -newConstant < rightSwipeExpandableWidth {
                // When swipe offset within swipExandable width, linear function
                // This makes cell move along with finger
                setExpandOffset(-newConstant, animated: false)
            }
            else {
                // When swipe offset exceeds swipeExpandable width, logarithm function
                // This makes cell moves with a hysteresis affect. (Make users feel they cannot move it furthermore)
                
                // Delta of X offset that exceeds swipeExpandable width
                let logDeltaX = max(-newConstant - rightSwipeExpandableWidth, 0)
                
                // New constant is composed with linear value + logarithm value (reduced value)
                setExpandOffset(rightSwipeExpandableWidth + (logDeltaX + log(1.0 + logDeltaX)) / 3.0, animated: false)
            }
            
        case .Ended, .Cancelled:
            let velocity = panRecognizer.velocityInView(contentView)
            // If swipe velocity is fast enough, expand cell without checking the width expanded.
            if velocity.x < -800 {
                expandRightSide(animated: true)
            }
            else {
                // If swipe slowly, check the width already expanded to determine whether expand or collapse.
                if -deltaX / rightSwipeExpandableWidth > 0.5 {
                    expandRightSide(animated: true)
                }
                else {
                    collapse(animated: true)
                }
            }
            
        default:
            break
        }
    }
    
    private dynamic func tapContentView(tapRecognizer: UITapGestureRecognizer) {
        let locationInContentView = tapRecognizer.locationInView(contentView)
        let swipeableContentViewFrameInContentView = swipeableContentView.convertRect(swipeableContentView.bounds, toView: contentView)
        let tappedOnSwipeableContentView = swipeableContentViewFrameInContentView.contains(locationInContentView)
        
        if tappedOnSwipeableContentView {
            collapse(animated: true)
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension SwipeTableViewCell {
    public override func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if rightSwipeEnabled == false {
            return false
        }
        
        if gestureRecognizer === tapRecognizer {
            // If is expanded, consume this touch, which disables selection of tableViewCell
            return rightSwipeExpanded
        }
        
        if gestureRecognizer === immediateTouchRecognizer {
            // Only one cell should be expanded, tap any cell will collapse all other cells
            collapseAllOtherCells()
            
            // If touches swipeable content view, collapse
            if rightSwipeExpanded == true {
                let locationInContentView = immediateTouchRecognizer.locationInView(contentView)
                let swipeableContentViewFrameInContentView = swipeableContentView.convertRect(swipeableContentView.bounds, toView: contentView)
                let touchedOnSwipeableContentView = swipeableContentViewFrameInContentView.contains(locationInContentView)
                
                if touchedOnSwipeableContentView {
                    collapse(animated: true)
                    return true
                }
                else {
                    return false
                }
            }
            else {
                return false
            }
        }
        
        if gestureRecognizer === panRecognizer {
            // Ref: http://stackoverflow.com/a/8603839/3164091
            let velocity = panRecognizer.velocityInView(nil)
            
            // Ignore touches if pans vertically
            if fabs(velocity.y) > fabs(velocity.x) {
                return false
            }
            
            // Expanded State: immediate touch gesture will collapse it, ignore pan gesture.
            if rightSwipeExpanded == true {
                return false
            }
            
            // Normal State
            guard isEmbeddedInScrollView() else { return true }
            guard let window = window else { return false }
            
            // Ignore screen edge pans
            let locationInWindow = panRecognizer.locationInView(window)
            // Ref: http://stackoverflow.com/a/14105964/3164091
            let locationInScreen = window.convertPoint(locationInWindow, toWindow: nil)
            let screenBounds = window.convertRect(window.bounds, toWindow: nil)
            
            // Pans on screen edges, should not expand cell.
            if locationInScreen.x < unscrollableScreenEdgeWidth || locationInScreen.x > screenBounds.width - unscrollableScreenEdgeWidth {
                return false
            }
            
            // Handle cases if tableView is on a scrollView. This usually the case there's a super page view controller.
            // Swipe: <--o
            if velocity.x < 0 {
                // Only handle pan if swipe slowly
                return abs(velocity.x) < cellScrollsVelocityThreshold
            }
            else {
                // Swipe: o-->
                return false
            }
        }
        
        return true
    }
    
    public override func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Immediate touch recognizer should be recognized with all other gesture recognizers
        if gestureRecognizer === immediateTouchRecognizer {
            return true
        }
        return false
    }
}

// MARK: - Automatic collapsing
extension SwipeTableViewCell {
    public override func prepareForReuse() {
        super.prepareForReuse()
        collapse(animated: true)
    }
    
    public override func willTransitionToState(state: UITableViewCellStateMask) {
        super.willTransitionToState(state)
        // Any cell state transition should collapse
        collapse(animated: true)
    }
    
    public override func willMoveToWindow(newWindow: UIWindow?) {
        super.willMoveToWindow(newWindow)
        
        // If newWindow is nil, tableView is about to deallic, remove observation to avoid crash.
        if newWindow == nil {
            removeTableViewContentOffsetObservation()
        }
    }
    
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        collapse(animated: true)
        addTableViewContentOffsetObservation()
    }
    
    public override func didMoveToSuperview() {
        super.didMoveToSuperview()
        // Did move to a new tableView, observe tableView's movement
        addTableViewContentOffsetObservation()
    }
    
    public override func willMoveToSuperview(newSuperview: UIView?) {
        super.willMoveToSuperview(newSuperview)
        // Remove observation of tableView if cell is move to another view
        removeTableViewContentOffsetObservation()
    }
    
    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        // Make sure new value exists
        guard let _ = change?[NSKeyValueChangeNewKey] else { return }
        collapse(animated: true)
    }
    
    private final func addTableViewContentOffsetObservation() {
        guard window != nil else { return }
        if isObservingTableView == true { return }
        guard let tableView = tableView else { return }
        tableView.addObserver(self, forKeyPath: "contentOffset", options: [.New], context: nil)
        isObservingTableView = true
    }
    
    private final func removeTableViewContentOffsetObservation() {
        if isObservingTableView == true {
            guard let tableView = tableView else { return }
            tableView.removeObserver(self, forKeyPath: "contentOffset")
            isObservingTableView = false
        }
    }
}

// MARK: - Private Helpers
extension SwipeTableViewCell {
    /**
     Whether the tableView managing this cell is embedded in a scrollView
     
     - returns: true if there's a such scrollView. Otherwise, false.
     */
    private final func isEmbeddedInScrollView() -> Bool {
        return tableView?.superviewOfType(UIScrollView) != nil
    }
}