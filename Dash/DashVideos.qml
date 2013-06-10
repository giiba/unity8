/*
 * Copyright (C) 2013 Canonical, Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.0
import Ubuntu.Components 0.1
import ListViewWithPageHeader 0.1
import "../Components"
import "../Components/ListItems" as ListItems
import "Video"

LensView {
    id: lensView
    property alias previewShown: previewLoader.onScreen

    property var categoryNames: [
        i18n.tr("Featured"),
        i18n.tr("Recent"),
        i18n.tr("New Releases"),
        i18n.tr("Popular Online")
    ]

    onIsCurrentChanged: {
        pageHeader.resetSearch();
    }

    onMovementStarted: categoryView.showHeader()

    Binding {
        target: lensView.lens
        property: "searchQuery"
        value: pageHeader.searchQuery
    }

    Connections {
        target: panel
        onSearchClicked: if (isCurrent) {
            pageHeader.triggerSearch()
            categoryView.showHeader()
        }
    }

    /* Workaround for bug: https://bugreports.qt-project.org/browse/QTBUG-28403
       When using Loader to load external QML file in the list deelgate, the ListView has
       a bug where it can position the delegate content to overlap the section header
       of the ListView - a workaround is to use sourceComponent of Loader instead */
    Component { id: videosFilterGrid; VideosFilterGrid {} }
    Component { id: videosCarousel;   VideosCarousel {}   }

    function getRenderer(categoryId) {
        switch (categoryId) {
            case 0: return videosCarousel
            default: return videosFilterGrid
        }
    }

    OpenEffect {
        id: effect
        anchors {
            fill: parent
            bottomMargin: -bottomOverflow
        }
        sourceItem: categoryView

        enabled: gap > 0.0

        topGapPx: (1 - gap) * positionPx
        topOpacity: Math.max(0, (1 - gap * 1.2))
        bottomGapPx: positionPx + gap * (targetBottomGapPx - positionPx)
        bottomOverflow: units.gu(6)
        bottomOpacity: 1 - (gap * 0.8)

        property int targetBottomGapPx: height - units.gu(8) - bottomOverflow
        property real gap: previewLoader.open ? 1.0 : 0.0

        Behavior on gap {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
                onRunningChanged: {
                    if (!previewLoader.open && !running) {
                        previewLoader.onScreen = false;
                    }
                }
            }
        }
    }

    ListViewWithPageHeader {
        id: categoryView
        anchors.fill: parent
        model: lensView.categories
//         clipListView: !previewLoader.onScreen

        onAtYEndChanged: if (atYEnd) endReached()
        onMovingChanged: if (moving && atYEnd) endReached()

        delegate: ListItems.Base {
            id: base
            highlightWhenPressed: false
            property int categoryIndex: index
            property int categoryId: id

            Loader {
                id: loader
                anchors { top: parent.top; left: parent.left; right: parent.right }
                sourceComponent: lensView.getRenderer(base.categoryId)
                onLoaded: {
                    item.model = results
                }
                asynchronous: true

                Connections {
                    target: loader.item
                    onClicked: {
                        var dataItem;
                        // VideosCarousel and VideosFilterGrid have different
                        // clicked signals, accomodate for that
                        if (categoryId == 0) {
                            var fileUri = delegateItem.model.column_0.replace(/^[^:]+:/, "")
                            dataItem = {fileUri: fileUri, nfoUri: delegateItem.model.column_5}
                        } else {
                            dataItem = data;
                        }
                        if (dataItem.nfoUri != "") {
                            previewLoader.videoData = dataItem;
                            previewLoader.open = true;
                            effect.positionPx = mapToItem(categoryView, 0, itemY).y;
                        }
                    }
                }
            }
        }

//         sectionProperty: "name"
//         sectionDelegate: ListItems.Header {
//             width: categoryView.width
//             text: i18n.tr(section)
//         }

        pageHeader: PageHeader {
            id: pageHeader
            width: categoryView.width
            text: i18n.tr("Videos")
            searchEntryEnabled: true
            searchHistory: lensView.searchHistory
        }
    }

    Loader {
        id: previewLoader
        height: effect.bottomGapPx - effect.topGapPx
        anchors {
            top: parent.top
            topMargin: effect.topGapPx
            left: parent.left
            right: parent.right
        }
        sourceComponent: onScreen ? previewComponent : undefined

        property bool open: false
        property bool onScreen: false
        property var videoData


        onOpenChanged: {
            if (open) {
                onScreen = true;
            }
        }

        onLoaded: {
            item.item = videoData;
        }
    }

    Component {
        id: previewComponent

        VideoPreview {
            id: preview
            anchors.fill: parent
            onClose: open = false;
        }
    }

    // TODO: Move as InverseMouseArea to DashPreview
    MouseArea {
        enabled: previewLoader.onScreen
        anchors {
            fill: parent
            topMargin: effect.bottomGapPx
        }
        onClicked: {
            previewLoader.open = false;
        }
    }

}
