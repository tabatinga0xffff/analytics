import React, { Fragment, useState, useCallback, useEffect, useRef } from 'react'
import { Transition } from '@headlessui/react'
import { ChevronDownIcon } from '@heroicons/react/20/solid'
import debounce from 'debounce-promise'
import classNames from 'classnames'

function Option({isHighlighted, onClick, onMouseEnter, text}) {
  const className = classNames('relative cursor-pointer select-none py-2 px-3', {
    'text-gray-900 dark:text-gray-300': !isHighlighted,
    'bg-indigo-600 text-white': isHighlighted,
  })

  return (
    <li
      className={className}
      onClick={onClick}
      onMouseEnter={onMouseEnter}
    >
      <span className="block truncate">{text}</span>
    </li>
  )
}

export default function PlausibleCombobox(props) {
  const [options, setOptions] = useState([])
  const [loading, setLoading] = useState(false)
  const [isOpen, setOpen] = useState(false);
  const [input, setInput] = useState('');
  const [highlightedIndex, setHighlightedIndex] = useState(0);
  const searchRef = useRef(null);
  const containerRef = useRef(null);

  function fetchOptions(query) {
    setLoading(true)
    setOpen(true)

    return props.fetchOptions(query).then((loadedOptions) => {
      setLoading(false)
      setHighlightedIndex(0)
      setOptions(loadedOptions)
    })
  }

  const debouncedFetchOptions = useCallback(debounce(fetchOptions, 200), [])

  function onInput(e) {
    const newInput = e.target.value
    setInput(newInput)

    if (!newInput.includes('*')) {
      debouncedFetchOptions(newInput)
    }
  }

  function toggleOpen() {
    if (!isOpen) {
      fetchOptions(input)
      searchRef.current.focus()
      setOpen(true)
    } else {
      setInput('')
      setOpen(false)
    }
  }

  function selectOption(option) {
    props.onChange([...props.values, option])
    setOpen(false)
    setInput('')
    searchRef.current.focus()
  }

  function removeOption(option, e) {
    e.stopPropagation()
    const newValues = props.values.filter((val) => val.value !== option.value)
    props.onChange(newValues)
    searchRef.current.focus()
    setOpen(false)
  }

  const handleClick = useCallback((e) => {
    if (containerRef.current && containerRef.current.contains(e.target)) return;

    setInput('')
    setOpen(false)
  })

  useEffect(() => {
    document.addEventListener("mousedown", handleClick, false);
    return () => { document.removeEventListener("mousedown", handleClick, false); }
  }, [])

  const isWildCard = !loading && input.includes('*')
  const matchesFound = !loading && !isWildCard && options.length > 0
  const noMatchesFound = !loading && !isWildCard && options.length === 0

  return (
    <div ref={containerRef} className="relative ml-2 w-full">
      <div onClick={toggleOpen} className={classNames('pl-2 pr-8 py-1 w-full dark:bg-gray-900 dark:text-gray-300 rounded-md shadow-sm border border-gray-300 dark:border-gray-700', {'border-indigo-500 ring-1 ring-indigo-500': isOpen, '': !isOpen})}>
        { props.values.map((value) => {
            return (
              <div key={value.value} className="bg-indigo-100 flex justify-between w-full rounded-sm px-2 py-0.5 m-0.5 text-sm">{value.label} <button onClick={(e) => removeOption(value, e)} className="font-bold ml-1">&times;</button></div>
            )
          })
        }
        <input className="border-none py-1 px-1 p-0 w-full inline-block rounded-md focus:outline-none focus:ring-0 text-sm" ref={searchRef} value={input} style={{backgroundColor: "inherit"}} placeholder={props.placeholder} type="text" onChange={onInput}></input>
        <div className="cursor-pointer absolute inset-y-0 right-0 flex items-center pr-2">
          {!loading && <ChevronDownIcon className="h-4 w-4 text-gray-500" />}
          {loading && <Spinner />}
        </div>
      </div>
      <Transition
        as={Fragment}
        leave="transition ease-in duration-100"
        leaveFrom="opacity-100"
        leaveTo="opacity-0"
        show={isOpen}
      >
        <ul className="z-50 absolute mt-1 max-h-60 w-full overflow-auto rounded-md bg-white py-1 text-base shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none sm:text-sm dark:bg-gray-900">
          { loading && (
            <div className="relative cursor-default select-none py-2 px-4 text-gray-700 dark:text-gray-300">
              Loading options...
            </div>
          )}
          { noMatchesFound && (
            <div className="relative cursor-default select-none py-2 px-4 text-gray-700 dark:text-gray-300">
              No matches found in the current dashboard. Try selecting a different time range or searching for something different
            </div>
          )}
          { matchesFound && (
            options.map((option, i) => {
              return (
                <Option
                  key={option.value}
                  isHighlighted={highlightedIndex === i}
                  onClick={() => selectOption(option)}
                  onMouseEnter={() => setHighlightedIndex(i)}
                  text={option.label}
                />
              )
            })
          )}
          { isWildCard && (
            <Option
              isHighlighted={true}
              onClick={() => selectOption({value: input, label: input})}
              text={`Filter by ${input}`}
              />
          )}
        </ul>
      </Transition>
    </div>
  );
}

function Spinner() {
  return (
    <svg className="animate-spin h-4 w-4 text-indigo-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
  )
}
