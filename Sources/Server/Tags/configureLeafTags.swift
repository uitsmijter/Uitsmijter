import Foundation
import Vapor
import Leaf

func configureLeafTags(_ leaf: Application.Leaf) {
    leaf.tags[IsNotEmptyThenTag.name] = IsNotEmptyThenTag()
    leaf.tags[TranslationTag.name] = TranslationTag()
}
