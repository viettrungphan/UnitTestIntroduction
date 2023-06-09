//
//  IntroduceToTDD.swift
//  UTIntroductionTests
//
//  Created by LAP15935 on 29/05/2023.
//

import XCTest
import Foundation


public class FeedItem {
    public init() {}
}

protocol FeedLoader {
    func loadFeed(onComplete: @escaping ([FeedItem])->(), onError: @escaping ((Error)->()))
}

struct AnyError: Error {}

class InjectableFeedLoader: FeedLoader {
    var items: [FeedItem] = []
    var error: AnyError?
    func loadFeed(onComplete: @escaping ([FeedItem])->(), onError: @escaping ((Error)->())) {
        if let error = error {
            onError(error)
            return
        }
        onComplete(items)
    }
}

public struct FeedLoaderMock: FeedLoader {
    internal init(loader: FeedLoader) {
        self.loader = loader
    }
    
    
    private let loader: FeedLoader
    func loadFeed(onComplete: @escaping ([FeedItem])->(), onError: @escaping ((Error)->())) {
        return loader.loadFeed(onComplete: onComplete, onError: onError)
    }
    
}

struct FallbackableFeedLoader: FeedLoader {
    let primary: FeedLoader
    let fallback: FeedLoader
   
    func loadFeed(onComplete: @escaping ([FeedItem])->(), onError: @escaping ((Error)->())) {
        primary.loadFeed { items in
            onComplete(items)
        } onError: { _ in
            fallback.loadFeed(onComplete: onComplete, onError: onError)
        }
    }
}

extension FeedLoader {
    func fallback(loader: FeedLoader) -> FeedLoader {
        FallbackableFeedLoader(primary: self, fallback: loader)
    }
    func retry(_ numberOfTime: Int) -> FeedLoader {
        var loader: FeedLoader = self
        for _ in 0..<numberOfTime {
            loader = loader.fallback(loader: self)
        }
        return loader
    }
}


final class IntroduceToTDD: XCTestCase {
    func test_init_ShouldReturnAnEmptyList() {
        //Given
        let (sut, _) = makeSUT()
        let exp = self.expectation(description: "Expect load list success")
        var list:[FeedItem] = []
        
        //When
        sut.loadFeed { _list in
            list = _list
            exp.fulfill()
        } onError: { _ in}
        
        //Then
        self.wait(for: [exp], timeout: 1)
        XCTAssertNotNil(list)
    }
    
    func test_load_ShouldReturnListOfItem() {
        let (sut, mock) = makeSUT()
        let exp = self.expectation(description: "Expect load list success")
        
        mock.items = [FeedItem()]
        
        sut.loadFeed { list in
            XCTAssertTrue(list.count > 0)
            exp.fulfill()
        } onError: { _ in
            fatalError("Should not fail")
        }
        self.wait(for: [exp], timeout: 1)
    }
    
    func test_load_ShouldFailed() {
        let (sut, mock) = makeSUT()
        let exp = self.expectation(description: "Expect load list fail")
        
        mock.error = AnyError()
        
        sut.loadFeed { list in
            fatalError("Should not success")
        } onError: { error in
            XCTAssertNotNil(error)
            exp.fulfill()
        }
        self.wait(for: [exp], timeout: 1)
    }

    func test_load_ShouldLoadCacheIfFailed() {
        let cache = InjectableFeedLoader()
        cache.items = ([FeedItem()])

        let network = InjectableFeedLoader()
        network.error = AnyError()
        
        let sut = network.fallback(loader: cache)
        
        let exp = self.expectation(description: "Expect load netwokfail then fall to cache ")

        sut.loadFeed { list in
            XCTAssertNotNil(list)
            exp.fulfill()
        } onError: { _ in
            fatalError("Should not fail")
            
        }
        self.wait(for: [exp], timeout: 1)
    }
    
    func test_load_ShouldRetry3TimesThenLoadCacheIfFailed() {
        let cache = InjectableFeedLoader()
        cache.items = ([FeedItem()])

        let network = InjectableFeedLoader()
        network.error = AnyError()
        
        let sut = network
            .retry(3)
            .fallback(loader: cache)
        
        let exp = self.expectation(description: "Expect load netwokfail then fall to cache ")

        sut.loadFeed { list in
            XCTAssertNotNil(list)
            exp.fulfill()
        } onError: { _ in
            fatalError("Should not fail")
            
        }
        self.wait(for: [exp], timeout: 1)
    }

}

extension IntroduceToTDD {
    func makeSUT() -> (sut: FeedLoader, mock: InjectableFeedLoader) {
        let mock = InjectableFeedLoader()
        let sut = FeedLoaderMock(loader: mock)
        return (sut, mock)
    }
}
