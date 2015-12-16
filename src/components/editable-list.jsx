import _ from 'underscore';
import classNames from 'classnames';
import ScrollRegion from './scroll-region';
import RetinaImg from './retina-img';
import React, {Component, PropTypes} from 'react';

/**
 * Renders a list of items and renders controls to add/edit/remove items.
 * It resembles OS X's default list component.
 * An item can be a React Component, a string or number.
 *
 * EditableList handles:
 * - Keyboard and mouse interactions to select an item
 * - Input to create a new item when the add button is clicked
 * - Callback to remove item when the remove button is clicked
 * - Double click to edit item, or use an edit button icon
 *
 * @param {object} props - props for EditableList
 * @param {(Component|string|number)} props.children - Items to be rendered by
 * the list
 * @param {number} props.selected - TODO
 * @param {string} props.className - CSS class to be applied to component
 * @param {boolean} props.allowEmptySelection - Determines wether the
 * EditableList will allow to have no selected items
 * @param {boolean} props.showEditIcon - Determines wether to show edit icon
 * button on selected items
 * @param {object} props.createInputProps - Props object to be passed on to
 * the create input element. However, keep in mind that these props can not
 * override the default props that EditableList will pass to the input.
 * @param {object} props.initialState - Used for testing purposes to initialize
 * the component with a given state.
 * @param {props.onCreateItem} props.onCreateItem
 * @param {props.onDeleteItem} props.onDeleteItem
 * @param {props.onItemEdited} props.onItemEdited
 * @param {props.onItemSelected} props.onItemSelected
 * @param {props.onItemCreated} props.onItemCreated
 * @class EditableList
 */
class EditableList extends Component {
  static displayName = 'EditableList'

  /**
   * If provided, this function will be called when the add button is clicked,
   * and will prevent an input to add items to be created inside the list
   * @callback props.onCreateItem
   */
  /**
   * If provided, this function will be called when the delete button is clicked.
   * @callback props.onDeleteItem
   * @param {(Component|string|number)} selectedItem - The selected item.
   * @param {number} idx - The selected item idx
   */
  /**
   * If provided, this function will be called when an item has been edited. This only
   * applies to items that are not React Components.
   * @callback props.onItemEdited
   * @param {string} newValue - The new value for the item
   * @param {(string|number)} originalValue - The original value for the item
   * @param {number} idx - The index of the edited item
   */
  /**
   * If provided, this function will be called when an item is selected via click or arrow
   * keys. If the selection is cleared, it will receive null.
   * @callback props.onItemSelected
   * @param {(Component|string|number)} selectedItem - The selected item or null
   * when selection cleared
   * @param {number} idx - The index of the selected item or null when selection
   * cleared
   */
  /**
   * If provided, this function will be called when the user has entered a value to create
   * a new item in the new item input. This function will be called when the
   * user presses Enter or when the input is blurred.
   * @callback props.onItemCreated
   * @param {string} value - The value for the new item
   */
  static propTypes = {
    children: PropTypes.arrayOf(PropTypes.oneOfType([
      PropTypes.string,
      PropTypes.number,
      PropTypes.element,
    ])),
    selected: PropTypes.number,
    className: PropTypes.string,
    allowEmptySelection: PropTypes.bool,
    showEditIcon: PropTypes.bool,
    createInputProps: PropTypes.object,
    onCreateItem: PropTypes.func,
    onDeleteItem: PropTypes.func,
    onItemEdited: PropTypes.func,
    onItemSelected: PropTypes.func,
    onItemCreated: PropTypes.func,
    initialState: PropTypes.object,
  }

  static defaultProps = {
    children: [],
    selected: null,
    className: '',
    allowEmptySelection: true,
    showEditIcon: false,
    createInputProps: {},
    onDeleteItem: ()=> {},
    onItemEdited: ()=> {},
    onItemSelected: ()=> {},
    onItemCreated: ()=> {},
  }

  constructor(props) {
    super(props);
    this._beganEditing = false;
    this.state = props.initialState || {
      editing: null,
      creatingItem: false,
    };
  }


  // Helpers

  _createItem = (value)=> {
    this._clearCreatingState(()=> {
      this.props.onItemCreated(value);
    });
  }

  _updateItem = (value, originalItem, idx)=> {
    this._clearEditingState(()=> {
      this.props.onItemEdited(value, originalItem, idx);
    });
  }

  _selectItem = (item, idx)=> {
    if (this.props.selected !== idx) {
      this.props.onItemSelected(item, idx);
    }
  }

  _clearEditingState = (callback)=> {
    this._setStateAndFocus({editing: null}, callback);
  }

  _clearCreatingState = (callback)=> {
    this._setStateAndFocus({creatingItem: false}, callback);
  }

  _setStateAndFocus = (state, callback = ()=> {})=> {
    this.setState(state, ()=> {
      this._focusSelf();
      callback();
    });
  }

  _focusSelf = ()=> {
    React.findDOMNode(this).focus();
  }

  /**
   * @private Scrolls to the dom node of the item at the provided index
   * @param {number} idx - Index of item inside the list to scroll to
   */
  _scrollTo = (idx)=> {
    if (!idx) return;
    const list = this.refs.itemsWrapper;
    const nodes = React.findDOMNode(list).querySelectorAll('.list-item');
    list.scrollTo(nodes[idx]);
  }


  // Handlers

  _onEditInputBlur = (event, item, idx)=> {
    this._updateItem(event.target.value, item, idx);
  }

  _onEditInputFocus = (event)=> {
    const input = event.target;
    this._beganEditing = false;
    // Move cursor to the end of the input
    input.selectionStart = input.selectionEnd = input.value.length;
  }

  _onEditInputKeyDown = (event, item, idx)=> {
    event.stopPropagation();
    if (_.includes(['Enter', 'Return'], event.key)) {
      this._updateItem(event.target.value, item, idx);
    } else if (event.key === 'Escape') {
      this._clearEditingState();
    }
  }

  _onCreateInputBlur = (event)=> {
    this._createItem(event.target.value);
  }

  _onCreateInputKeyDown = (event)=> {
    event.stopPropagation();
    if (_.includes(['Enter', 'Return'], event.key)) {
      this._createItem(event.target.value);
    } else if (event.key === 'Escape') {
      this._clearCreatingState();
    }
  }

  _onItemClick = (event, item, idx)=> {
    this._selectItem(item, idx);
  }

  _onItemEdit = (event, item, idx)=> {
    if (!React.isValidElement(item)) {
      this._beganEditing = true;
      this.setState({editing: idx});
    }
  }

  _onListBlur = ()=> {
    if (!this._beganEditing && this.props.allowEmptySelection) {
      this._selectItem(null, null);
    }
  }

  _onListKeyDown = (event)=> {
    const len = this.props.children.length;
    const handle = {
      'ArrowUp': (sel)=> Math.max(0, sel - 1),
      'ArrowDown': (sel)=> sel === len - 1 ? sel : sel + 1,
      'Escape': (sel)=> this.props.allowEmptySelection ? null : sel,
    };
    const selected = (handle[event.key] || ((sel)=> sel))(this.props.selected);
    this._scrollTo(selected);
    this._selectItem(this.props.children[selected], selected);
  }

  _onCreateItem = ()=> {
    if (this.props.onCreateItem) {
      this.props.onCreateItem();
    } else {
      this.setState({creatingItem: true});
    }
  }

  _onDeleteItem = ()=> {
    const idx = this.state.selected;
    const selectedItem = this.props.children[idx];
    if (selectedItem) {
      // Move the selection 1 up after deleting
      const len = this.props.children.length;
      const newlySelected = len === 1 ? null : Math.max(0, this.state.selected - 1);
      const newlySelectedItem = this.props.children[newlySelected];
      this._selectItem(newlySelectedItem, newlySelected);

      this.props.onDeleteItem(selectedItem, idx);
    }
  }


  // Renderers

  _renderEditInput = (item, idx, handlers = {})=> {
    const onInputBlur = handlers.onInputBlur || this._onEditInputBlur;
    const onInputFocus = handlers.onInputFocus || this._onEditInputFocus;
    const onInputKeyDown = handlers.onInputKeyDown || this._onEditInputKeyDown;

    return (
      <input
        autoFocus
        type="text"
        placeholder={item}
        defaultValue={item}
        onBlur={_.partial(onInputBlur, _, item, idx)}
        onFocus={onInputFocus}
        onKeyDown={_.partial(onInputKeyDown, _, item, idx)} />
    );
  }

  /**
   * @private Will render the create input with the provided input props.
   * Provided props will be overriden with the props that EditableList needs to
   * pass to the input.
   */
  _renderCreateInput = ()=> {
    const props = _.extend(this.props.createInputProps, {
      autoFocus: true,
      type: 'text',
      onBlur: this._onCreateInputBlur,
      onKeyDown: this._onCreateInputKeyDown,
    });

    return (
      <div className="create-item-input" key="create-item-input">
        <input {...props}/>
      </div>
    );
  }

  // handlers object for testing
  _renderItem = (item, idx, editing = this.state.editing, selected = this.props.selected, handlers = {})=> {
    const onClick = handlers.onClick || this._onItemClick;
    const onEdit = handlers.onEdit || this._onItemEdit;

    const classes = classNames({
      'list-item': true,
      'component-item': React.isValidElement(item),
      'editable-item': !React.isValidElement(item),
      'selected': selected === idx,
      'with-edit-icon': this.props.showEditIcon && editing !== idx,
    });
    let itemToRender = item;
    if (React.isValidElement(item)) {
      itemToRender = item;
    } else if (editing === idx) {
      itemToRender = this._renderEditInput(item, idx, handlers);
    }

    return (
      <div
        className={classes}
        key={idx}
        onClick={_.partial(onClick, _, item, idx)}
        onDoubleClick={_.partial(onEdit, _, item, idx)}>
        {itemToRender}
        <RetinaImg
          className="edit-icon"
          name="edit-icon.png"
          title="Edit Item"
          mode={RetinaImg.Mode.ContentIsMask}
          onClick={_.partial(onEdit, _, item, idx)} />
      </div>
    );
  }

  _renderButtons = ()=> {
    return (
      <div className="buttons-wrapper">
        <div className="btn-editable-list" onClick={this._onCreateItem}>
          <span>+</span>
        </div>
        <div className="btn-editable-list" onClick={this._onDeleteItem}>
          <span>—</span>
        </div>
      </div>
    );
  }

  render() {
    let items = this.props.children.map((item, idx)=> this._renderItem(item, idx));
    if (this.state.creatingItem === true) {
      items = items.concat(this._renderCreateInput());
    }

    return (
      <div
        className={`nylas-editable-list ${this.props.className}`}
        tabIndex="1"
        onBlur={this._onListBlur}
        onKeyDown={this._onListKeyDown} >
        <ScrollRegion
          className="items-wrapper"
          ref="itemsWrapper" >
          {items}
        </ScrollRegion>
        {this._renderButtons()}
      </div>
    );
  }

}

/**
 * @private
 * TODO Refactor decorators outside of this file
 * This Higher order component makes the EditableList behave like a "Controlled"
 * component, similar to React's controlled form inputs.
 *
 * If the parent component provides a `selected` prop, it becomes the parent's
 * responsibility to provide the `onItemSelected` callback to update the selection
 * inside the list -- if the callback isn't provided, the selection wont be updated.
 * E.g.:
 *
 * ```
 * _onItemSelected(item, idx) {
 *   this.setState({selected: idx});
 * }
 *
 * render() {
 *   <EditableList selected={this.state.selected} onItemSelected={this._onItemSelected}>
 *     {this.state.items}
 *   </EditableList>
 * }
 * ```
 *
 * If the `selected` prop is not provided, the list will manage the selection
 * state automatically (internally).
 */
const ControlledList = (List)=> {
  return (
    class extends Component {
      static propTypes = {
        selected: PropTypes.number,
        allowEmptySelection: PropTypes.bool,
        onItemSelected: PropTypes.func,
      }

      static defaultProps = {
        allowEmptySelection: true,
        onItemSelected: ()=> {},
      }

      constructor(props) {
        super(props);
        this.state = {
          selected: props.allowEmptySelection ? null : 0,
        };
      }

      _onItemSelected = (item, idx)=> {
        this.setState({selected: idx});
        this.props.onItemSelected(item, idx);
      }

      render() {
        if (this.props.selected != null) {
          return <List {...this.props} />;
        }
        return <List {...this.props} selected={this.state.selected} onItemSelected={this._onItemSelected} />;
      }
    }
  );
};

export default ControlledList(EditableList);
